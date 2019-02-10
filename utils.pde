class FloatingPoint
{
  public float x;
  public float y;
  
  public FloatingPoint(float x, float y){
    this.x = x;
    this.y = y;
  }
  
  public float[] compareTo(FloatingPoint o){
    return new float[]{o.x - this.x, o.y - this.y};
  }
}
