/**
 * Represents preset cell styles for the Palette class.
 */
public enum PaletteStyle 
{
  /**
   * CLASSIC mirrors the old Windows 98/2000/XP Paint color palette, with 14 columns, 
   * two rows, and a set of primary and mixed colors.
   */
  CLASSIC, 
  
  /**
   * GRAYSCALE mimics a range of grayscale color shades, from 0 (BLACK) to 255 (WHITE), 
   * in a linear gradient dependent on the number of set cells.
   */
  GRAYSCALE, 
  
  /**
   * MONOCHROME only contains two colors; 0 (BLACK) and 255 (WHITE). Odd-numbered rows 
   * of cells are entirely black, even-numbered rows are entirely white.
   */
  MONOCHROME, 
  
  /**
   * EMPTY sets all cells to 0 (WHITE), and is intended to be used in circumstances 
   * when the developer wishes to implement their own custom palette.
   */
  EMPTY
}

/**
 * Represents a customizable and renderable on-screen palette of selectable colors, in classic Paint style.
 */
class Palette
{
  // Constants:
  public static final float CELL_SIZE = 25.0f; // Width/height for palette cells
  public static final float PREVIEW_CELL_SIZE = CELL_SIZE * 2.0f; // Width/height for the selected color preview cell
  public static final float INTER_CELL_GAP = CELL_SIZE / 4.0f; // Space between each cell in the grid
  public static final int DEFAULT_ROW_LENGTH = 14; // The default maximum cell grid row length; used if no argument is provided in the constructor
  public final color DEFAULT_BG_COLOR = color(236, 233, 216); // The default background color for the palette UI
  
  // Instance variables
  private color[][] cells; // The index containing all of the colors to be displayed
                           // The index is organized exactly as it is displayed
  private float scale; // The decimal scaling factor for the entire UI
  private float borderWidth; // The width (in pixels) of the background border around the UI. Not affected by scaling
  private FloatingPoint[][] cellBounds; // The actual on-screen X/Y coordinates of each cell in the index when it was last rendered
  private color BG; // The current background color
  private color currentColor; // The currently chosen color, displayed in the preview cell
  private FloatingPoint lastCoords; // The last coordinates this UI was drawn at
  private FloatingPoint lastSize; // The outer bounds of this UI the last time it was drawn
  
  /**
   * Short-form constructor. Omits the row-length argument in favor of using the default length field.
   * @param style the {@link PaletteStyle color set} to use for setup.
   * @param scale the scale factor for the entire UI in percent. Value <= 0 will be ignored. 100% is default scaling.
   * @param borderWidth the width (in pixels) of the background border around the UI. Unaffected by the scale factor.
   */
  public Palette(PaletteStyle style, float scale, float borderWidth){
    this(style, scale, DEFAULT_ROW_LENGTH, borderWidth);
  }
  
  /**
   * Full constructor.
   * @param style the {@link PaletteStyle color set} to use for setup.
   * @param scale the scale factor for the entire UI in percent. Value <= 0 will be ignored. 100% is default scaling.
   * @param len the maximum length of each row of cells. Cells will wrap around when their row hits the maximum length.
   *            Some styles will override this setting with their own row limits.
   * @param borderWidth the width (in pixels) of the background border around the UI. Unaffected by the scale factor.
   */
  public Palette(PaletteStyle style, float scale, int len, float borderWidth)
  {
    // Generate style from provided preset
    generateFromStyle(style, len);
    
    // Set initial values for instance variables
    this.scale = (scale / 100.0f);
    this.borderWidth = borderWidth;
    BG = DEFAULT_BG_COLOR;
    currentColor = -1;
    lastCoords = new FloatingPoint(-1, -1);
    lastSize = new FloatingPoint(0, 0);
    
    // Ensure that the scale is in bounds
    this.scale = this.scale <= 0.0f ? 100.0f : this.scale;
  }
  
  /**
   * Renders this palette to the screen at the specified coordinates.
   * Recalculates cell bounds and updates the preview color once complete.
   */
  public void render(float x, float y)
  {
    // Check if this UI has moved since it was last redrawn
    boolean hasMoved = !(lastCoords.x == x && lastCoords.y == y);
    
    // Store draw position values
    lastCoords = new FloatingPoint(x, y);
    
    // Storage for draw cursor position
    float currentX = x;
    float currentY = y;
    
    // Calculate the outer bounds of the entire palette assembly with current cells and scale settings
    float prevCellSize = PREVIEW_CELL_SIZE + (INTER_CELL_GAP * (cells.length - 1));  
    float calcW = (cells[0].length * (CELL_SIZE + INTER_CELL_GAP)) + prevCellSize;
    float calcH = (cells.length * CELL_SIZE) + ((cells.length - 1) * INTER_CELL_GAP);
    calcW *= scale;
    calcH *= scale;
    prevCellSize *= scale;
    calcW += borderWidth * 2;
    calcH += borderWidth * 2;
    
    // Register the bounds of this element
    lastSize = new FloatingPoint(calcW, calcH);
    
    // Draw background
    noStroke();
    fill(BG);
    rect(currentX, currentY, calcW, calcH);
    stroke(0);
    
    // Draw preview cell and advance X-marker to the start of the row section
    currentX += borderWidth;
    currentY += borderWidth;
    fill(currentColor == Integer.MIN_VALUE ? cells[0][0] : currentColor);
    rect(currentX, currentY, prevCellSize, prevCellSize);
    currentX += prevCellSize;
    
    // Track the starting X-coordinate of the row portion for easy row-wrapping
    float rowStartX = currentX;
    
    // Draw cells
    for(int i = 0; i < cells.length; i++)
    {
      for(int j = 0; j < cells[i].length; j++)
      {
        // Draw inter-cell gap and then the cell itself
        currentX += INTER_CELL_GAP * scale;
        fill(cells[i][j]);
        rect(currentX, currentY, CELL_SIZE * scale, CELL_SIZE * scale);
        
        // Store cell graphic bounds to the cell bound index
        if(hasMoved) cellBounds[i][j] = new FloatingPoint(currentX, currentY);
        currentX += CELL_SIZE * scale;
      }
      
      // Move down one row if we have another row to draw, otherwise it doesn't matter where the cursor is
      currentY += (INTER_CELL_GAP + CELL_SIZE) * scale;
      currentX = rowStartX;
    }
  }
  
  /**
   * Gets the color cell, if any, whose bounding box collides with the provided coordinates.
   * If a cell does collide with said coordinates, this palette's internal color selection registry will be updated
   * to reflect the selected cell.
   */
  public color getChosenColor(float x, float y)
  {
    color chosen = Integer.MIN_VALUE;
    
    // Iterate through each cell in the index, checking its bounds for collision. If one matches, record it and break both loops.
    rowIter:
    for(int i = 0; i < cells.length; i ++){
      for(int j = 0; j < cells[i].length; j++){
        FloatingPoint p = cellBounds[i][j];
        if((x >= p.x && x <= p.x + CELL_SIZE * scale) && (y >= p.y && y <= p.y + CELL_SIZE * scale)){
          chosen = cells[i][j];
          break rowIter;
        }
      }
    }
    
    // Only update the internal tracking variable if a cell matched
    this.currentColor = chosen == Integer.MIN_VALUE ? currentColor : chosen;
    return chosen;
  }
  
  /**
   * Manually selects the color at the specified row and column indices.
   * This only updates this palette's internal selection register, and does
   * not return the specified color.
   */
  public void selectColor(int row, int col){
    currentColor = cells[row][col];
  }
  
  /**
   * Selects a color that may or may not be in this palette's selection index.
   * This does not alter any of the existing colors in the index, just the preview cell.
   */
  public void selectCustomColor(color c){
    currentColor = c;
  }
  
  /**
   * Gets the sizes of this palette's cell matrix.
   * @returns the sizes of the cell array. Index 0 is row count, index 1 is column count (AKA maximum row length).
   */
  public int[] getPaletteIndexSize(){
    return new int[]{cells.length, cells[0].length};
  }
  
  /**
   * Gets the color in the cell at the specified row and column.
   */
  public color getColorAt(int row, int col){
    return cells[row][col];
  }
  
  /**
   * Sets the color in the cell at the specified row and column indices to the specified color.
   */
  public void setColorAt(int row, int col, color set){
    cells[row][col] = set;
  }
  
  /**
   * Sets the background color of this palette to the specified color.
   * Note that this does not affect the colors inside the cells themselves.
   */
  public void setBGColor(color c){
    this.BG = c;
  }
  
  /**
   * Gets the color that was last chosen, either manually or via collision check.
   * Will return -1 if no color has yet been chosen.
   */
  public color getLastSelectedColor(){
    return currentColor;
  }
  
  /**
   * Gets the last set of relative outer bounds of this object as it was rendered.
   */
  public FloatingPoint getBounds(){
    return lastSize;
  }
  
  // Internal method called from the constructor.
  private void generateFromStyle(PaletteStyle style, int len)
  {
    // Take action based on what preset style is being used:
    switch(style)
    {
      // CLASSIC mirrors the old Windows 98/2000/XP Paint color palette, with 14 columns, two rows, and a set of primary and mixed colors.
      case CLASSIC:
        cells = new color[][]
                  {{color(0), color(128), color(128,0,0), color(128,128,0), color(0,128,0), color(0,128,128), color(0,0,128), color(128,0,128), 
                    color(128,128,64), color(0,64,64), color(0,128,255), color(0,64,128), color(128,0,255), color(128,64,0)}, 
                    
                  {color(255), color(192), color(255,0,0), color(255,255,0), color(0,255,0), color(0,255,255), color(0,0,255), color(255,0,255), 
                   color(255,255,128), color(0,255,128), color(128,255,255), color(128,128,255), color(255,0,128), color(255,128,64)}};
      break;
      
      // GRAYSCALE mimics a range of grayscale color shades, from 0 (BLACK) to 255 (WHITE), in a linear gradient dependent on the number of set cells.
      case GRAYSCALE:
        cells = new color[2][len];
        // Calculate the increment between each cell in the matrix
        int increment = 255 / (cells.length * cells[0].length);
        for(int i = 0; i < cells.length; i++)
          for(int j = 0; j < cells[i].length; j++){
            // Set the cell's color to the appropriate multiple of the increment value for its position.
            int calc = ((i * cells[i].length) + j) * increment;
            cells[i][j] = color(255 - (calc > 255 ? 255 : calc));
          }
            
      break;
      
      // MONOCHROME only contains two colors; 0 (BLACK) and 255 (WHITE). The top row of cells is entirely black, and the bottow row is entirely white.
      case MONOCHROME:
        cells = new color[2][len];
        for(int i = 0; i < cells.length; i++)
          for(int j = 0; j < cells[i].length; i++)
            if((i + 1) % 2 == 0)
              cells[i][j] = color(0);
            else
              cells[i][j] = color(255);
      break;
      
      // EMPTY sets all cells to 0 (WHITE), and is intended to be used in circumstances when the developer wishes to implement their own custom palette.
      case EMPTY:
        cells = new color[2][len];
        for(int i = 0; i < cells.length; i++)
          for(int j = 0; j < cells[i].length; j++)
            cells[i][j] = color(0);
      break;
      
      // Just initialize the index to all-0 entries if an invalid style value is provided
      default:
        cells = new color[2][len];
    }
    
    // Initialize the cell bound index to the same dimensions as the cell index.
    cellBounds = new FloatingPoint[cells.length][cells[0].length];
  }
}
