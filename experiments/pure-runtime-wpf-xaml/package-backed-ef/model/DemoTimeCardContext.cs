using System.IO;
using Microsoft.EntityFrameworkCore;

namespace Challenge1;

public sealed class DemoTimeCardContext : DbContext
{
    public DbSet<DemoTimeCard> TimeCards => Set<DemoTimeCard>();

    protected override void OnConfiguring(DbContextOptionsBuilder options)
    {
        // EXPERIMENT COPY: only change vs baseline (besides internal->public): isolated, cwd-relative DB folder
        // instead of %LOCALAPPDATA%\ModernChallenge1 (owner-approved).
        var directory = Path.Combine("artifacts", "ef-run");

        Directory.CreateDirectory(directory);
        options.UseSqlite($"Data Source={Path.Combine(directory, "demo-timecards.db")}");
    }

    public DemoTimeCardContext()
    {
        Database.EnsureCreated();
    }
}
