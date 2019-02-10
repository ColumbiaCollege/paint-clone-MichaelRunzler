import javax.swing.JOptionPane.*;
import java.awt.image.BufferedImage;
import javax.swing.ImageIcon;
import java.util.ArrayDeque;

import static javax.swing.JOptionPane.*;

// Constants
public final int UNDO_MAXIMUM = 10; // Maximum number of undo frames

// UI elements
Palette colors;
ToolBox tools;
Ribbon ribbon;

// Instance variables and state tracking
FloatingPoint paletteCoords; // Color palette starting coordinates
FloatingPoint toolCoords; // Toolbox starting coordinates
FloatingPoint ribbonCoords; // Ribbon starting coordinates
FloatingPoint canvasCoords; // Canvas X/Y starting coordinates
FloatingPoint canvasSize; // Canvas W/H dimensions
boolean ribbonSelected; // This flag is set when at least one ribbon button is selected via mouseover
boolean inCanvas; // This flag is set when the mouse cursor has a custom graphic attached to it
HashMap<Integer, Boolean> mouseButtonMap; // Map of all currently depressed mouse buttons
PImage loaded; // Cache for any loaded images from the openFileSelection method
color customColorCache; // Cache for user-defined custom color sets
ArrayDeque<PImage> undo; // Cache for undo stack frames

void setup()
{
  // Set up canvas
  size(1024, 1024);
  background(color(0));
  
  // Set up instance variables
  ribbonSelected = false;
  inCanvas = false;
  mouseButtonMap = new HashMap<Integer, Boolean>();
  loaded = null;
  customColorCache = Integer.MIN_VALUE;
  undo = new ArrayDeque<PImage>();
  
  // Set initial render coordinates for UI groups
  paletteCoords = new FloatingPoint(0, height - 80);
  toolCoords = new FloatingPoint(0, 50);
  ribbonCoords = new FloatingPoint(0, 0);
  
  // Initialize UI group elements
  colors = new Palette(PaletteStyle.CLASSIC, 100.0f, 10);
  tools = new ToolBox(100.0f, 10, new PencilTool(), new MarkerTool(), new EraserTool(), new PickerTool());
  ribbon = new Ribbon(50.0f, 20);
  
  // Test-render the color palette to figure out how high it will be
  colors.render(paletteCoords.x, paletteCoords.y);
  
  // Adjust the height that the color palette renders at to ensure that it aligns with the bottom of the canvas
  background(0);
  paletteCoords.y = height - colors.getBounds().y;
  
  // Render UI groups and filler background
  colors.render(paletteCoords.x, paletteCoords.y);
  tools.render(toolCoords.x, toolCoords.y);
  addRibbonButtons();
  ribbon.render(ribbonCoords.x, ribbonCoords.y);
  drawUIBG();
  
  // Calculate available canvas space
  canvasCoords = new FloatingPoint(tools.getBounds().x, ribbon.getBounds().y);
  canvasSize = new FloatingPoint(width - tools.getBounds().x, paletteCoords.y - ribbon.getBounds().y);
  
  // Draw blank canvas
  blankCanvas();
}

// Draws filler background behind all UI group elements to make them appear contiguous
void drawUIBG()
{
  noStroke();
  fill(tools.DEFAULT_BG_COLOR);
  // Filler between tool and palette elements
  rect(0, toolCoords.y + tools.getBounds().y, tools.getBounds().x, paletteCoords.y - (toolCoords.y + tools.getBounds().y));
  // Filler between palette and screen edge
  rect(colors.getBounds().x, paletteCoords.y, width - colors.getBounds().x, colors.getBounds().y);
  // Filler between ribbon and screen edge
  rect(ribbon.getBounds().x, 0, width - ribbon.getBounds().x, ribbon.getBounds().y);
  stroke(0);
}

// Add buttons to ribbon
void addRibbonButtons()
{
  ribbon.addRibbonButton(new Button("Open...", color(0), new ActionEvent<Void>(){
    public Void action(){
      // Since loading an image will blank the canvas first, confirm before proceeding.
      if(showConfirmDialog(null, "This will discard any unsaved changes! Continue?", "Warning", YES_NO_OPTION) == 0)
        selectInput("Open a file...", "openFileSelection");
      return null;
    }
  }));
  
  ribbon.addRibbonButton(new Button("Save", color(0), new ActionEvent<Void>(){
    public Void action(){
      selectOutput("Save to file...", "saveFileSelection");
      return null;
    }
  }));
  
  ribbon.addRibbonButton(new Button("Undo", color(0), new ActionEvent<Void>(){
    public Void action(){
      undo();
      return null;
    }
  }));
  
  ribbon.addRibbonButton(new Button("Clear Canvas", color(0), new ActionEvent<Void>(){
    public Void action(){
      // Confirm first, then blank the canvas
      if(showConfirmDialog(null, "This will clear the entire canvas! Continue?", "Warning", YES_NO_OPTION) == 0) 
        blankCanvas();
      return null;
    }
  }));
  
  ribbon.addRibbonButton(new Button("Custom Colors...", color(0), new ActionEvent<Void>(){
    public Void action()
    {
      String[] desc = new String[]{"RED", "GREEN", "BLUE"};
      int[] values = new int[desc.length];
      boolean complete = true;
      
      // Show a series of dialog boxes, one for each color, requesting user input.
      for(int i = 0; i < desc.length; i++)
      {
        String res = showInputDialog("Input a value for " + desc[i] + ":", "(0-255)");
        int resI = 0;
        // If the user cancelled, abort the entire operation.
        if(res == null){
          complete = false;
          break;
        }
        // Make sure the input is valid. If it isn't, decrement the counter so that we keep showing
        // this dialog until the user inputs valid data or cancels.
        try{
          resI = Integer.parseInt(res);
          if(resI < 0 || resI > 255) throw new IllegalArgumentException();
          values[i] = resI;
        }catch(Exception e){ 
          i--;
        }
      }
      
      // Once we have all three color values, inform the user of the next step, and store the custom value in the cache.
      if(complete){
        customColorCache = color(values[0], values[1], values[2]);
        
        // Generate the preview image for the dialog.
        BufferedImage c = new BufferedImage(40, 40, BufferedImage.TYPE_INT_ARGB);
        for(int i = 0; i < c.getWidth(); i++)
          for(int j = 0; j < c.getHeight(); j++)
            c.setRGB(i, j, customColorCache);
        
        // Display the notice dialog
        showMessageDialog(null, "Click on a palette slot to assign your new color to it.\n" +
                                "Right-click anywhere to cancel.", "Message", INFORMATION_MESSAGE, new ImageIcon(c));
      }
      
      return null;
    }
  }));
}

void blankCanvas(){
  noStroke();
  fill(255);
  rect(canvasCoords.x, canvasCoords.y, canvasSize.x, canvasSize.y);
  stroke(0);
}

void undo(){
  if(undo.size() == 0){
    showMessageDialog(null, "Cannot undo; no undo phases left!");
    return;
  }
  
  image(undo.pop(), canvasCoords.x, canvasCoords.y);
}

boolean checkCanvasCollision(float x, float y){
  return (x > canvasCoords.x && x < canvasCoords.x + canvasSize.x) 
      && (y > canvasCoords.y && y < canvasCoords.y + canvasSize.y);
}

void draw()
{
  // Render selection state on the main ribbon. 
  // If the ribbon was previously selected, and now isn't, update it to reflect that change.
  Button chosen = ribbon.getChosenButton(mouseX, mouseY);
  if(chosen != null){
    ribbon.render(ribbonCoords.x, ribbonCoords.y);
    ribbonSelected = true;
  }else if(ribbonSelected){
    ribbon.selectButtonAt(-1);
    ribbon.render(ribbonCoords.x, ribbonCoords.y);
  }
  
  // Draw passive or active tool cursor if the mouse is within the active canvas area
  if(checkCanvasCollision(mouseX, mouseY))
    {
      // If the cursor was not in the canvas on the last draw phase, clear the mouse button
      // hold register to avoid accidental drag operations.
      if(!inCanvas)
        for(int i : mouseButtonMap.keySet()) mouseButtonMap.put(i, false);
      
      // Parse mouse button hold list and draw active cursor for any held buttons
      boolean active = false;
      for(int i : mouseButtonMap.keySet()){
        if(mouseButtonMap.get(i)){
          tools.getLastSelectedTool().renderDraw(mouseX, mouseY, colors.getLastSelectedColor(), i);
          active = true;
        }
      }
      
      // Draw passive cursor if it has not already been set
      if(!inCanvas){
        tools.getLastSelectedTool().getCursorGraphic();
        inCanvas = true;
      }
      
      // If a button is being held and the color picker is active, update the active color palette's preview cell with the picker's current color
      if(active && tools.getLastSelectedTool().getClass() == PickerTool.class){
        colors.selectCustomColor(((PickerTool)tools.getLastSelectedTool()).picked);
        colors.render(paletteCoords.x, paletteCoords.y);
      }
  }else if(inCanvas){
    // If the cursor is no longer inside the canvas area, and was 
    // on the last draw phase, set it back to the standard mouse cursor icon
    cursor(ARROW);
    inCanvas = false;
  }
  
  // Load the image in the cache, if there is one, then clear the cache.
  if(loaded != null){
    blankCanvas();
    image(loaded, canvasCoords.x, canvasCoords.y);
    loaded = null;
  }
}

void mousePressed()
{
  // Mark the button as active
  mouseButtonMap.put(mouseButton, true);
  
  if(mouseButton == LEFT)
  {
    // If the mouse cursor graphic flag is set, the cursor is inside the canvas and cannot
    // currently be colliding with a UI element, so we can skip bounds checking entirely.
    // Yay, optimization!
    if(inCanvas)
    {
      // Since the cursor is guaranteed to be in the canvas area, we can assume that a draw operation is being initiated.
      // Store current canvas state to undo stack.
      undo.push(get((int)canvasCoords.x, (int)canvasCoords.y, (int)canvasSize.x, (int)canvasSize.y));
      if(undo.size() > UNDO_MAXIMUM) undo.removeLast();
    }
    
    color c = Integer.MIN_VALUE;
    Tool t = null;
    ToolSize s = null;
    Button b = null;
   
    // Try each bounds check in succession, only trying as many as we need until we get a hit.
    c = colors.getChosenColor(mouseX, mouseY);
    if(c == Integer.MIN_VALUE) t = tools.getChosenTool(mouseX, mouseY);
    if(c == Integer.MIN_VALUE && t == null) s = tools.getChosenSize(mouseX, mouseY);
    if(c == Integer.MIN_VALUE && t == null && s == null) b = ribbon.getChosenButton(mouseX, mouseY);
    
    // Update the render of whichever UI element had the collision hit
    if(c != Integer.MIN_VALUE)
    {
      // If there is a custom color in the cache, assign it first, then re-render
      if(customColorCache != Integer.MIN_VALUE)
      {
        // Find which color is currently being selected by the user
        int[] paletteSize = colors.getPaletteIndexSize();
        int[] found = new int[]{-1, -1};
        rowIter:
        for(int i = 0; i < paletteSize[0]; i++)
          for(int j = 0; j < paletteSize[1]; j++)
            if(colors.getColorAt(i, j) == c){
              found[0] = i;
              found[1] = j;
              break rowIter;
            }
        
        // If the user clicked a valid palette slot, set it to the custom color and clear the cache
        if(found[0] > -1 && found[1] > -1){
          colors.setColorAt(found[0], found[1], customColorCache);
          colors.selectColor(found[0], found[1]);
          customColorCache = Integer.MIN_VALUE;
        }
      }
      
      colors.render(paletteCoords.x, paletteCoords.y);
    }
    
    if(t != null || s != null) tools.render(toolCoords.x, toolCoords.y);
    if(b != null) b.onClicked.action();
  }else if(mouseButton == RIGHT)
  {
    // If the custom color cache has a color in it, clear it.
    if(customColorCache != Integer.MIN_VALUE){
      showMessageDialog(null, "Custom color assignment cancelled.");
      customColorCache = Integer.MIN_VALUE;
    }
  }
} //<>//

void mouseReleased(){
  // Mark the button as inactive
  mouseButtonMap.put(mouseButton, false);
}

//
// Callbacks
//

void openFileSelection(File selection)
{
  // Check to ensure that a valid file was selected
  if(selection == null || !selection.exists()) return;
  
  // Load the image. If it is an improper format that the sketch cannot load, return.
  PImage source = loadImage(selection.getAbsolutePath());
  if(source == null){
    // If the read failed due to an I/O error, notify the user.
    showMessageDialog(null, "File load failed! Ensure that you have specified a valid image\n" +
                            "file (.png, .jpg/.jpeg, .gif, or .tga), and try again.");
    return;
  }
  
  // Check bounds. If the loaded image is smaller than or the same size as the canvas, return it as-is.
  if(source.width <= canvasSize.x && source.height <= canvasSize.y){
    loaded = source;
    return;
  }
  
  // If the loaded image is larger than the canvas, resize it, preserving aspect ratio, to fit in the canvas space.
  boolean aspect = false; //<>//
  aspect = source.width >= source.height;
  source.resize(aspect ? (int)canvasSize.x : 0, aspect ? 0 : (int)canvasSize.y);
  loaded = source;
}

void saveFileSelection(File selection)
{
  // Check to make sure the destination file is a valid path and does not exist.
  if(selection == null) return;
  
  // Ensure that the destination file has either (a) no file extension, or (b) a .png/.jpeg/.tga file extension.
  String ext = selection.getName();
  if(ext.contains(".")) ext = ext.substring(ext.lastIndexOf('.'), ext.length());
  
  // If the extension does not match any of the recognized formats, tag a .png extension onto it.
  if(!ext.contains(".") || !(ext.equals(".png") || ext.equals(".jpg") || ext.equals(".jpeg") || ext.equals(".tga"))){
    selection = new File(selection.getParentFile(), selection.getName() + ".png");
  }
  
  // If the destination exists, the user has already verified that they would like to delete it through
  // the file chooser dialog. Delete the existing file and notify the user if the operation fails.
  if(selection.exists() && !selection.delete()){
    showMessageDialog(null, "Unable to delete existing file. Try a different filename.");
    return;
  }
  
  // Capture the canvas, and write the capture to the file.
  // If any of these operations fail, abort the operation.
  get((int)canvasCoords.x, (int)canvasCoords.y, (int)canvasSize.x, (int)canvasSize.y).save(selection.getAbsolutePath());
  
  // Notify the user if the operation failed to write the file.
  if(!selection.exists())
    showMessageDialog(null, "File write failed! Check paths and try a different filename.");
}
