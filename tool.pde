/**
 * A range of tool sizes for use by subclasses of the Tool base class. 
 * The actual dimensions of each size are determined by the tool in question.
 */
enum ToolSize{
  PIXEL, SMALL, MEDIUM, LARGE, XL, XXL
}

/**
 * The base class for all canvas tools. 
 * Contains basic methods and fields for use by the ToolBox API.
 */
abstract class Tool
{
  // The current size of this tool.
  protected ToolSize size;
  
  // Whether this tool will react to sizing changes via #setSize.
  protected boolean isSizeable;
  
  // The icon to display on the tool's selector
  protected PImage graphic;
  
  // The icon to use for the mouse cursor while this tool is active
  protected PImage cursorGraphic;
  
  // Default constructor. Sets the tool size to SMALL as the default.
  public Tool(){
    size = ToolSize.SMALL;
    isSizeable = true;
    graphic = null;
    cursorGraphic = null;
  }
  
  /**
   * Updates the active cursor to the proper graphic for this tool type.
   * Tools that have no active cursor image should leave this method unchanged.
   * @param c the color the tool should preview in. Some tools may not use this value.
   */
  public void getCursorGraphic(){
    cursor(ARROW);
  }
  
  /**
   * Renders the 'active' or drawing component of this tool.
   * This typically draws to the canvas itself, as opposed to rendering the tool hover preview.
   * @param x the X-coordinate to initiate drawing
   * @param y the Y-coordinate to initiate drawing
   * @param c the color with which to draw. Some tools may not use this value.
   * @param button the mouse button that is being pressed to initiate this action
   */
  public void renderDraw(float x, float y, color c, int button){}
  
  /**
   * Completes a drawing operation initiated using {@link #renderDraw}.
   * Operations such as these are typically click-and-drag or multi-click operations, such
   * as lines or selections. Single-mode tools (such as pencils or fill tools) will probably not
   * use this method, in which case it will do nothing.
   * @param x the X-coordinate at which drawing is to be completed
   * @param y the Y-coordinate at which drawing is to be completed
   * @param c the color with which to draw. Some tools may not use this value.
   * @param button the mouse button that was released to complete this action
   */
  public void renderComplete(float x, float y, color c, int button){}
  
  /**
   * Reports whether this tool react to sizing changes or not.
   */
  public boolean isSizeable(){
    return isSizeable;
  }
  
  /**
   * Gets the tool's current size.
   */
  public ToolSize getSize(){
    return this.size;
  }
  
  /**
   * Sets this tool's size to the specified size value.
   * The actual tool size on-screen varies by tool.
   */
  public void setSize(ToolSize size){
    this.size = size;
  }
  
  /**
   * Gets this tool's icon. Note that this is not to be used for the draw preview,
   * only for the icon on UI elements.
   */
  public PImage getIcon(){
    return graphic;
  }
}

/**
 * Represents a renderable 'toolbox' of selectable tools on-screen.
 */
class ToolBox
{
  // Constants
  public final color DEFAULT_BG_COLOR = color(236, 233, 216); // The default background color for the toolbox
  public static final float CELL_SIZE = 40.0f; // The width/height of each tool cell in the toolbox
  public static final float INTER_CELL_GAP = CELL_SIZE / 4.0f; // The gap between each cell in the grid
  public static final float SIZE_SELECTOR_HEIGHT = CELL_SIZE / 2.0f; // The height of each size selector button
  public static final float SIZE_SELECTOR_BORDER_WIDTH = 2.0f; // Size of the gap around the edge of each size selector button
  public static final int MAX_COLUMN_LENGTH = 8; // The maximum number of tools that may be displayed in each column
  public static final float SELECTED_BORDER_WIDTH = 3.0f; // The width of the border displyed around a tool cell when it is selected
  public final color SELECTED_BORDER_COLOR = color(128); // The color of the above border
  
  // Instance variables
  private color BG; // The current background color
  private float scale; // The current decimal scale of the entire toolbox UI
  private Tool[][] tools; // The index of all tool cells in this toolbox. Ordered exactly as it is rendered.
  private FloatingPoint[][] cellBounds; // The actual on-screen X/Y coordinates of each cell in the grid
  private FloatingPoint[] sizeSelectorBounds; // The actual on-screen X/Y coordinates of each size selector cell
  private int[] selected; // The row/column of the currently selected tool
  private float borderWidth; // The width of the background border around the tool UI
  private boolean sizeCollision; // Whether to check collision on the sizing selector section of the UI
  private FloatingPoint lastCoords; // The last coordinates this UI was drawn at
  private FloatingPoint lastSize; // The outer bounds of this UI the last time it was drawn
  private float sizeSelectorWidth; // The last width of the size selector element
  
  /**
   * Standard constructor.
   * @param scale the scale factor for the entire toolbox UI in percent. Values <= 0 will be ignored. 100% is default scaling.
   * @param tools an array of tools to add to the toolbox. These will be automatically mapped to rows and columns as space allows.
   */
  public ToolBox(float scale, float borderWidth, Tool... tools)
  {
    // Initialize instance variables
    BG = DEFAULT_BG_COLOR;
    this.scale = scale / 100.0f;
    selected = new int[2];
    this.borderWidth = borderWidth;
    sizeSelectorBounds = new FloatingPoint[ToolSize.values().length];
    sizeCollision = false;
    lastCoords = new FloatingPoint(-1, -1);
    lastSize = new FloatingPoint(0, 0);
    sizeSelectorWidth = 0.0f;
    
    // Calculate the size of the tool index based off the tool list provided
    this.tools = new Tool[(int)Math.ceil((double)tools.length / (double)MAX_COLUMN_LENGTH)][MAX_COLUMN_LENGTH];
    
    // Propogate the provided tool list into the storage index according to the grid layout
    colIter:
    for(int i = 0; i < this.tools.length; i++)
      for(int j = 0; j < this.tools[0].length; j++){
        int target = (i * MAX_COLUMN_LENGTH) + j;
        if(target >= tools.length) break colIter;
        this.tools[i][j] = tools[target];
      }
    
    // Initialize the cell bounds tracking index to the same dimensions as the tool index
    cellBounds = new FloatingPoint[this.tools.length][this.tools[0].length];
  }
  
  public void render(float x, float y)
  {
    // Get registry of all tool sizing values from the enum
    ToolSize[] tsValues = ToolSize.values();
    
    // Check if this UI has moved since it was last redrawn
    boolean hasMoved = !(lastCoords.x == x && lastCoords.y == y);
    
    // Store draw position values
    lastCoords = new FloatingPoint(x, y);
    
    float currentX = x;
    float currentY = y;
    
    // Calculate scaled UI sizes before rendering
    float calcW = (tools.length * CELL_SIZE) + ((tools.length - 1) * INTER_CELL_GAP);
    float calcH = (tools[0].length * CELL_SIZE) + (((tools[0].length + tsValues.length) - 1) * INTER_CELL_GAP) + (tsValues.length * SIZE_SELECTOR_HEIGHT);
    calcW *= scale;
    calcH *= scale;
    calcW += borderWidth * 2;
    calcH += borderWidth * 2;
    
    // Register the bounds of this element
    lastSize = new FloatingPoint(calcW, calcH);
    
    sizeSelectorWidth = calcW - (borderWidth * 2);
    
    // Draw background
    noStroke();
    fill(BG);
    rect(currentX, currentY, calcW, calcH);
    stroke(0);
    
    // Advance draw pointer to the start of the tool cell group
    currentX += borderWidth;
    currentY += borderWidth;
    
    // Cache markers for the start of the cell group
    float cellStartY = currentY;
    float cellStartX = currentX;
    
    // Draw cells
    for(int i = 0; i < tools.length; i++)
    {
      for(int j = 0; j < tools[i].length; j++)
      {
        // Draw the tool's icon and outline
        if(tools[i][j] != null)
        {
          // Draw outline around the tool cell if it is selected
          if(selected[0] == i && selected[1] == j){
            noStroke();
            fill(SELECTED_BORDER_COLOR);
            rect(currentX - (SELECTED_BORDER_WIDTH * scale), currentY - (SELECTED_BORDER_WIDTH * scale), 
                (CELL_SIZE * scale) + (SELECTED_BORDER_WIDTH * 2), (CELL_SIZE  * scale) + (SELECTED_BORDER_WIDTH * 2));
            stroke(0);
          }
          
          // Draw the tool's icon if it has one
          if(tools[i][j].getIcon() != null){
            PImage img = tools[i][j].getIcon();
            img.resize((int)(CELL_SIZE * scale), (int)(CELL_SIZE * scale));
            image(img, currentX, currentY);
          }
        }
        
        // Cache current cell coordinates to the bounds cache if invalidated and advance the draw pointer, including the inter-cell gap
        if(hasMoved) cellBounds[i][j] = new FloatingPoint(currentX, currentY);
        currentY += (CELL_SIZE + INTER_CELL_GAP) * scale;
      }
       
      // Reset the cursor to the start of the cell group for the next draw cycle, and move to the next column.
      // Skip reset and move operations if this draw phase was for the last column.
      if(i < tools.length - 1){
        currentY = cellStartY;
        currentX += (CELL_SIZE + INTER_CELL_GAP) * scale;
      }
    }
    
    // Jump back to the end of the cell group to draw the sizing area
    currentX = cellStartX;
    
    // Draw sizing area if the current tool supports it
    if(tools[selected[0]][selected[1]] != null && tools[selected[0]][selected[1]].isSizeable())
    {
      // Update sizing selector collision flag
      sizeCollision = true;
      
      for(int i = 0; i < tsValues.length; i++)
      {
        // Draw selection background if this size is selected, or just the outline if it is not
        fill(i == tools[selected[0]][selected[1]].getSize().ordinal() ? 128 : BG);
        rect(currentX, currentY, sizeSelectorWidth, SIZE_SELECTOR_HEIGHT * scale);
        
        // Cache current sizing cell coordinates to the sizing bounds cache if invalidated
        if(hasMoved) sizeSelectorBounds[i] = new FloatingPoint(currentX, currentY);
        
        // Calculate the width of the sizing line in this sizing cell
        float lineWidth = 3.0f * i;
        if(lineWidth == 0) lineWidth = 1.0f;
        lineWidth *= scale;
        
        // Cache a local version of the Y-pointer for manipulation
        float tmpY = currentY;
        // Advance the cached draw pointer and draw the sizing line
        tmpY += ((SIZE_SELECTOR_HEIGHT * scale) - lineWidth) / 2;
        currentX += SIZE_SELECTOR_BORDER_WIDTH * scale;
        fill(0);
        rect(currentX, tmpY, sizeSelectorWidth - ((SIZE_SELECTOR_BORDER_WIDTH * 2) * scale), lineWidth);
        
        // Advance Y pointer and reset X pointer
        currentY += (SIZE_SELECTOR_HEIGHT + INTER_CELL_GAP) * scale;
        currentX = cellStartX;
      }
    }else{
      // Update sizing selector collision flag
      sizeCollision = false;
    }
  }
  
  /**
   * Gets the tool cell, if any, whose bounding box collides with the provided coordinates.
   * If a cell does collide with said coordinates, it will be displayed as selected on the next render call.
   */
  public Tool getChosenTool(float x, float y)
  {
    int[] chosen = new int[]{-1, -1};
   
    // Iterate through each set of cached cell bounds, checking if they collide with the provided coordinates
    colIter:
    for(int i = 0; i < tools.length; i++){
      for(int j = 0; j < tools[i].length; j++){
        FloatingPoint p = cellBounds[i][j];
        if((x >= p.x && x <= p.x + (CELL_SIZE * scale)) && (y >= p.y && y <= p.y + (CELL_SIZE * scale))){
          chosen[0] = i;
          chosen[1] = j;
          break colIter;
        }
      }
    }
    
    // Only update internal selection pointer if a cell matched, and the cell is visible and in use
    if(chosen [0] != -1 && chosen[1] != -1 && tools[chosen[0]][chosen[1]] != null){
      selected = chosen;
      return tools[chosen[0]][chosen[1]];
    } else return null;
  }
  
  /**
   * Gets the size selector cell, if any, whose bounding box collides with the provided coordinates.
   * Calls to this method will always return null if the currently selected tool does not support sizing.
   * If a cell does collide with said coordinates, it will be displayed as selected on the next render call.
   */
  public ToolSize getChosenSize(float x, float y)
  {
    int chosen = -1;
    // Return immediately if the size selector UI is invisible at the moment
    if(!sizeCollision) return null;
    
    // Iterate through the cached size selector cell bounds, checking if they collide with the provided coordinates
    for(int i = 0; i < sizeSelectorBounds.length; i++){
      FloatingPoint p = sizeSelectorBounds[i];
      if((x >= p.x && x <= p.x + sizeSelectorWidth) && (y >= p.y && y <= p.y + (SIZE_SELECTOR_HEIGHT * scale))){
        chosen = i;
        break;
      }
    }
    
    // Only update the selected tool's size if a cell matched
    if(chosen != -1){
      tools[selected[0]][selected[1]].setSize(ToolSize.values()[chosen]);
      return ToolSize.values()[chosen];
    }else return null;
  }
  
  /**
   * Selects the tool at the specified row and column.
   * The selected cell will be displayed as such on the next render call unless it is empty. 
   */
  public void selectTool(int col, int row)
  {
    selected[0] = col;
    selected[1] = row;
  }
  
  /**
   * Selects the specified tool size from the size selection UI.
   * If the current tool does not support sizing, no action will be taken.
   */
  public void selectToolSize(ToolSize size)
  {
    if(!sizeCollision) return;
    tools[selected[0]][selected[1]].setSize(size);
  }
  
  /**
   * Gets the tool at the specified row and column.
   * This method does not bounds-check, so it is possible that an ArrayIndexOutOfBoundsException
   * will be thrown.
   */
  public Tool getToolAt(int col, int row){
    return tools[col][row];
  }
  
  /**
   * Adds a tool to the tool box at the next available tool cell. If no cells are available,
   * a new column will be created and the tool will be added to the top of that column.
   */
  public void addTool(Tool t)
  {
    // Try to add the tool to the first available spot in the last (or only) column.
    for(int i = 0; i < MAX_COLUMN_LENGTH; i++){
      // If the current index is free, add the new tool to it and return.
      if(tools[tools.length - 1][i] == null){
        tools[tools.length - 1][i] = t;
        return;
      }
    }
    
    // If there were no empty spots in the last column, add a new column.
    
    // Create temporary destination array
    Tool[][] temp = new Tool[tools.length + 1][MAX_COLUMN_LENGTH];
    
    // Copy all existing columns from index
    for(int i = 0; i < tools.length; i++)System.arraycopy(tools[i], 0, temp[i], 0, tools[i].length);
    
    // Reassign index to point to new array
    tools = temp;
    
    // Now that we have a new column, add the new tool to the first spot in it.
    tools[tools.length - 1][0] = t;
  }
  
  /**
   * Gets the last set of relative outer bounds of this object as it was rendered.
   */
  public FloatingPoint getBounds(){
    return lastSize;
  }
  
  /**
   * Sets the background color of this toolbox to the specified color.
   */
  public void setBGColor(color c){
    this.BG = c;
  }
  
  /**
   * Gets the tool that was last chosen, either manually or via collision check.
   * Will return {@code null} if no tool has yet been chosen.
   */
  public Tool getLastSelectedTool(){
    return tools[selected[0]][selected[1]];
  }
}



//
// TOOLS
//



class PencilTool extends Tool
{
  public static final float BASE_SIZE = 5.0f;
  
  public PencilTool(){
    super();
    super.graphic = loadImage("pencil.png");
    super.cursorGraphic = loadImage("pencil.png");
  }
  
  public void getCursorGraphic(){
    cursor(cursorGraphic, 8, cursorGraphic.height);
  }
  
  public void renderDraw(float x, float y, color c, int button)
  {
    if(button != LEFT) return;
    
    // Draw a colored square of the specified size at the current location
    rectMode(CENTER);
    fill(c);
    noStroke();
    float rad = 1.0f + (super.size.ordinal() * 4.0f);
    rect(x, y, rad, rad);
    rectMode(CORNER);
    stroke(0);
  }
}


class MarkerTool extends Tool
{
  public static final float BASE_DIAMETER = 5.0f;
  
  public MarkerTool(){
    super();
    super.graphic = loadImage("brush.png");
    super.cursorGraphic = loadImage("brush_passive.png");
  }
  
  public void getCursorGraphic(){
    cursor(cursorGraphic, cursorGraphic.width / 2, cursorGraphic.height / 2);
  }
  
  public void renderDraw(float x, float y, color c, int button)
  {
    if(button != LEFT) return;
    
    // Draw a colored circle of the specified size at the current location
    ellipseMode(CENTER);
    fill(c);
    noStroke();
    float rad = 1.0f + (super.size.ordinal() * 4.0f);
    ellipse(x, y, rad, rad);
    ellipseMode(CORNER);
    stroke(0);
  }
}


class PickerTool extends Tool
{
  public color picked;
  
  public PickerTool(){
    super();
    super.isSizeable = false;
    picked = color(0);
    super.graphic = loadImage("picker.png");
    super.cursorGraphic = loadImage("picker_passive.png");
  }
  
  public void getCursorGraphic(){
    cursor(cursorGraphic, 4, cursorGraphic.height);
  }
  
  public void renderDraw(float x, float y, color c, int button)
  {
    if(button != LEFT) return;
    
    // Get the pixel color at the current mouse coordinates
    loadPixels();
    picked = pixels[(int)((width * y) + x)];
  }
}


class EraserTool extends Tool
{
  public EraserTool(){
    super();
    super.graphic = loadImage("eraser.png");
    createGraphic();
  }
  
  public void getCursorGraphic(){
    cursor(cursorGraphic, cursorGraphic.width / 2, cursorGraphic.height / 2);
  }
  
  public void renderDraw(float x, float y, color c, int button)
  {
    if(button != LEFT) return;
    
    // Draw a white square of the specified size at the current location
    rectMode(CENTER);
    fill(255);
    noStroke();
    float rad = 1.0f + (super.size.ordinal() * 4.0f);
    rect(x, y, rad, rad);
    rectMode(CORNER);
    stroke(0);
  }
  
  public void setSize(ToolSize size)
  {
    super.setSize(size);
    createGraphic();
  }
  
  private void createGraphic()
  {
    // Calculate new size
    int rad = 2 + (super.size.ordinal() * 3);
    
    // Create empty image of the correct size for the cursor
    PImage target = createImage(32, 32, ARGB);
    
    // Calculate minimum and maximum X/Y coordinates of the actual icon
    int tX = (int)((target.width - rad) / 2);
    int tY = (int)((target.height - rad) / 2);
    int[] bounds = new int[]{tX, tY, tX + rad, tY + rad};
    
    // Iterate through each pixel in the image
    for(int y = 0; y < target.height; y++)
    {
      for(int x = 0; x < target.width; x++)
      {
        // If the pixel is within the bounds of the icon:
        if((x >= bounds[0] && x <= bounds[2]) && (y >= bounds[1] && y <= bounds[3])){
          // If the pixel is on the border, color it black
          if((x == bounds[0] || x == bounds[2]) || (y == bounds[1] || y == bounds[3])) target.set(x, y, color(0));
          // If the pixel is inside the border, color it white
          else target.set(x, y, color(255));
        }
        // For all pixels outside the icon, color to alpha
        else target.set(x, y, color(0, 0, 0, 0));
      }
    }
    
    super.cursorGraphic = target;
  }
}
