import java.util.Collections;

class Ribbon
{
  // Constants
  public final color DEFAULT_BG_COLOR = color(236, 233, 216); // The default background color
  public final color STROKE_COLOR = color(128); // The default button boundary color
  public final color SELECTION_COLOR = color(84, 128, 160);
  public static final float BUTTON_PADDING = 4.0f; // The size of the padding between the text and the edge of each button
  public static final float INTER_BUTTON_SPACING = 8.0f; // The space between each button and its neighbor
  public static final float RIBBON_PADDING = 8.0f; // The size of the gap between the edges of the buttons and the edge of the ribbon itself
  
  // Instance variables
  private color BG; // The current background color
  private int scale; // The size of the font for each button in pixels
  private ArrayList<Button> buttons; // List of all currently registered buttons
  private float[][] buttonBounds; // Cache of the actual on-screen bounds of each button as rendered
  private float h; // Set height of the ribbon
  private FloatingPoint lastCoords; // The last coordinates this UI was drawn at
  private FloatingPoint lastSize; // The outer bounds of this UI the last time it was drawn
  private int selected; // The currently selected button
  private boolean buttonSizeChanged; // If any buttons have been added since the last draw phase
  
  /**
   * Standard constructor.
   * @param h the minimum height of the ribbon bar. If this value is too small for the set text size, 
   *          the ribbon will expand as far as it has to.
   * @param scale the size of the text on the ribbon bar buttons in Processing font size
   * @param buttons initial buttons to add to the ribbon
   */
  public Ribbon(float h, int scale, Button... buttons)
  {
    // Initialize instance variables
    BG = DEFAULT_BG_COLOR;
    this.scale = scale;
    this.h = h;
    this.buttons = new ArrayList<Button>();
    this.buttonBounds = new float[buttons != null ? buttons.length : 0][4];
    lastCoords = new FloatingPoint(-1, -1);
    lastSize = new FloatingPoint(0, 0);
    selected = -1;
    buttonSizeChanged = false;
    
    // Add initially provided buttons to the registry if there are any
    if(buttons != null && buttons.length != 0) Collections.addAll(this.buttons, buttons);
  }
  
  /**
   * Render the ribbon at the specified coordinates on-screen.
   * Also updates collision data and adds any new buttons.
   */
  public void render(float x, float y)
  {
    // Set text scaling to the proper value
    textSize(scale);
    
    // Check to see if the UI has moved since the last draw phase
    boolean hasMoved = !(lastCoords.x == x && lastCoords.y == y);
    lastCoords = new FloatingPoint(x, y);

    float currentX = x;
    float currentY = y;
    
    // Calculate width and height
    float calcW = ((buttons.size() - 1) * INTER_BUTTON_SPACING) + (RIBBON_PADDING * 2);
    for(int i = 0; i < buttons.size(); i++){
      calcW += textWidth(buttons.get(i).text) + (BUTTON_PADDING * 2);
    }
    
    float calcH = (RIBBON_PADDING * 2) + (BUTTON_PADDING * 2) + (textAscent() + textDescent());
    if(calcH < h) calcH = h;
    
    // Register the bounds of this element
    lastSize = new FloatingPoint(calcW, calcH);
    
    // Draw background
    noStroke();
    fill(BG);
    rect(currentX, currentY, calcW, calcH);
    
    // Advance draw pointer to the start of the button cell area
    currentX += RIBBON_PADDING;
    currentY += RIBBON_PADDING;
    
    // If the button index has changed size since the last draw phase, update the bounding index to match its new size
    if(buttonSizeChanged) buttonBounds = new float[buttons.size()][4];
    
    // Calculate cell height and draw button cells
    float bH = calcH - (RIBBON_PADDING * 2);
    for(int i = 0; i < buttons.size(); i++)
    {
      // Calculate individual cell width
      Button b = buttons.get(i);
      float bW = textWidth(b.text) + (BUTTON_PADDING * 2);
      
      // Store this cell's collision data if it has been invalidated
      if(hasMoved || buttonSizeChanged) buttonBounds[i] = new float[]{currentX, currentY, bW, bH};
      
      // Draw button background/selection state
      color fill = BG;
      if(i == selected){
        fill = SELECTION_COLOR;
        stroke(SELECTION_COLOR);
      }else{
        stroke(STROKE_COLOR);
      }
      
      fill(fill);
      rect(currentX, currentY, bW, bH);
      
      // Draw button text
      fill(b.textColor);
      textAlign(CENTER, CENTER);
      text(b.text, currentX + (bW / 2.0f), currentY + ((bH / 2.0f) - BUTTON_PADDING));
      
      // Move to next button
      currentX += bW + INTER_BUTTON_SPACING;
    }
    
    // Clear button index size change flag
    buttonSizeChanged = false;
  }
  
  /**
   * Gets the menu button, if any, whose bounding box collides with the provided coordinates.
   * If a cell does collide with said coordinates, it will be shown as selected on the next render call.
   */
  public Button getChosenButton(float x, float y)
  {
    int chosen = -1;
    
    // Iterate through each cell in the index, checking its bounds for collision. 
    for(int i = 0; i < buttonBounds.length; i++){
       float[] p = buttonBounds[i];
       if((x >= p[0] && x <= p[0] + p[2]) && (y >= p[1] && y <= p[1] + p[3])){
         chosen = i;
         break;
       }
    }
    
    // Only update the internal tracking variable if a cell matched
    if(chosen != -1){
      this.selected = chosen;
      return buttons.get(chosen);
    }else return null;
  }
  
  /**
   * Selects the button at the specified index.
   */
  public void selectButtonAt(int index){
    selected = index;
  }
  
  /**
   * Adds a button to the end of the ribbon.
   */
  public void addRibbonButton(Button b)
  {
    // Add button to the index, and flag the bounding array size as having changed
    buttons.add(b);
    buttonSizeChanged = true;
  }
  
  /**
   * Sets the background color of this ribbon bar to the specified color.
   */
  public void setBGColor(color c){
    this.BG = c;
  }
  
  /**
   * Gets the last set of relative outer bounds of this object as it was rendered.
   */
  public FloatingPoint getBounds(){
    return lastSize;
  }
}

/**
 * Data-storage object type representing a clickable button.
 */
class Button
{
  public final color DEFAULT_TEXT_COLOR = color(0);
  
  public String text;
  public color textColor;
  public ActionEvent onClicked;
  
  public Button(String text, color textColor, ActionEvent onClicked)
  {
    this.text = text;
    this.textColor = textColor;
    this.onClicked = onClicked;
  }
}

/**
 * Used for executing an on-demand event from a button click or similar.
 */
abstract class ActionEvent <T>
{
  public abstract T action();
}
