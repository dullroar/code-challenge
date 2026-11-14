namespace LinqChallenge2;

internal sealed class TimecardEntry
{
    public int Id { get; set; }
    public DateOnly WorkDate { get; set; }
    public double Hours { get; set; }
    public required string Description { get; set; }
    public Guid RunId { get; set; }
}
