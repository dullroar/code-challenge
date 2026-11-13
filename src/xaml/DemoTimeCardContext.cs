using System.IO;
using Microsoft.EntityFrameworkCore;

namespace Challenge1;

public sealed class DemoTimeCardContext : DbContext
{
    public DbSet<DemoTimeCard> TimeCards => Set<DemoTimeCard>();

    protected override void OnConfiguring(DbContextOptionsBuilder options)
    {
        // Copy of the baseline types: public instead of internal, and the DB lives in ./data.
        var directory = "data";

        Directory.CreateDirectory(directory);
        options.UseSqlite($"Data Source={Path.Combine(directory, "demo-timecards.db")}");
    }

    public DemoTimeCardContext()
    {
        Database.EnsureCreated();
    }
}
