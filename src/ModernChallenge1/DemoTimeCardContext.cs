using System.IO;
using Microsoft.EntityFrameworkCore;

namespace Challenge1;

internal sealed class DemoTimeCardContext : DbContext
{
    public DbSet<DemoTimeCard> TimeCards => Set<DemoTimeCard>();

    protected override void OnConfiguring(DbContextOptionsBuilder options)
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ModernChallenge1");

        Directory.CreateDirectory(directory);
        options.UseSqlite($"Data Source={Path.Combine(directory, "demo-timecards.db")}");
    }

    public DemoTimeCardContext()
    {
        Database.EnsureCreated();
    }
}
