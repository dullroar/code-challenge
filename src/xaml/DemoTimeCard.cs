namespace Challenge1;

public sealed class DemoTimeCard
{
    public int Id { get; set; }
    public required string Category { get; set; }
    public double Hours { get; set; }
    public required string UserId { get; set; }
    public int Year { get; set; }
    public int Week { get; set; }
    public bool IsDemo { get; set; }
}
