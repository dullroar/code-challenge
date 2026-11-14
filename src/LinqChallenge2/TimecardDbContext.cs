using System.IO;
using Microsoft.EntityFrameworkCore;

namespace LinqChallenge2;

internal sealed class TimecardDbContext : DbContext
{
    public DbSet<TimecardEntry> Timecards => Set<TimecardEntry>();

    protected override void OnConfiguring(DbContextOptionsBuilder options)
    {
        // LINQ_CHALLENGE_DATA_DIR lets check.ps1 point this at a throwaway directory
        // instead of the real per-user data folder.
        var directory = Environment.GetEnvironmentVariable("LINQ_CHALLENGE_DATA_DIR")
            ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "LinqChallenge2");

        Directory.CreateDirectory(directory);
        options.UseSqlite($"Data Source={Path.Combine(directory, "timecards.db")}");
    }

    public TimecardDbContext()
    {
        Database.EnsureCreated();
    }
}
