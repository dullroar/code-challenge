# Constrained track: not built

Per plan section 6/8, the constrained track applies only where an imperative capability remains outside XAML. None remained: strict built-in, package-backed (SQLite) and package-backed (EF Core) compositions each ran the whole demo from runtime XAML (see `../evidence/final-report.md`). No imperative escape hatch was introduced, so there is no constrained composition and nothing to audit here. The only C# in the experiment is the generic probe host and the owner-approved EF model copy.
