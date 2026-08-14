using System.ComponentModel;
using System.Globalization;

namespace ClpHostedAgent.Tools;

public static class ProductivityDataTools
{
    private static readonly Lazy<List<ProductivityRecord>> _records = new(LoadData);
    private static readonly Lazy<List<Department>> _departments = new(LoadDepartments);
    private static readonly Lazy<List<JobCategory>> _jobCategories = new(LoadJobCategories);

    [Description("Query productivity percent data. Returns Required Worked Hours and Actual Worked Hours by date, department, and job category. Productivity Percent = Required Worked Hours / Actual Worked Hours. Optionally filter by department name (partial match), job category name, and/or date range (yyyy-MM-dd format).")]
    public static string QueryProductivityData(
        [Description("Optional partial department name to filter by (e.g. 'Emergency', 'Nursing')")] string? departmentFilter = null,
        [Description("Optional job category name to filter by (e.g. 'RN', 'Clerical', 'Other Support')")] string? jobCategoryFilter = null,
        [Description("Optional start date in yyyy-MM-dd format")] string? startDate = null,
        [Description("Optional end date in yyyy-MM-dd format")] string? endDate = null)
    {
        var records = _records.Value.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(departmentFilter))
        {
            var deptIds = _departments.Value
                .Where(d => d.Name.Contains(departmentFilter, StringComparison.OrdinalIgnoreCase))
                .Select(d => d.Id)
                .ToHashSet();
            records = records.Where(r => deptIds.Contains(r.DepartmentId));
        }

        if (!string.IsNullOrWhiteSpace(jobCategoryFilter))
        {
            var catIds = _jobCategories.Value
                .Where(j => j.Name.Equals(jobCategoryFilter, StringComparison.OrdinalIgnoreCase))
                .Select(j => j.Id)
                .ToHashSet();
            records = records.Where(r => catIds.Contains(r.JobCategoryId));
        }

        if (DateTime.TryParse(startDate, out var start))
            records = records.Where(r => r.Date >= start);

        if (DateTime.TryParse(endDate, out var end))
            records = records.Where(r => r.Date <= end);

        var results = records.ToList();

        if (results.Count == 0)
            return "No data found matching the specified filters.";

        var totalRequired = results.Sum(r => r.RequiredWorkedHours);
        var totalActual = results.Sum(r => r.ActualWorkedHours);
        var productivityPercent = totalActual > 0 ? (totalRequired / totalActual) * 100 : 0;

        var byDept = results
            .GroupBy(r => r.DepartmentId)
            .Select(g =>
            {
                var dept = _departments.Value.FirstOrDefault(d => d.Id == g.Key);
                var req = g.Sum(x => x.RequiredWorkedHours);
                var act = g.Sum(x => x.ActualWorkedHours);
                var pct = act > 0 ? (req / act) * 100 : 0;
                return new { Department = dept?.Name ?? $"Dept {g.Key}", Required = req, Actual = act, ProductivityPct = pct, RecordCount = g.Count() };
            })
            .OrderByDescending(x => x.RecordCount)
            .Take(15)
            .ToList();

        var summary = $"Summary: {results.Count} records found.\n" +
                      $"Total Required Worked Hours: {totalRequired:F2}\n" +
                      $"Total Actual Worked Hours: {totalActual:F2}\n" +
                      $"Overall Productivity Percent: {productivityPercent:F1}%\n\n" +
                      "Breakdown by Department (top 15):\n" +
                      string.Join("\n", byDept.Select(d =>
                          $"  {d.Department}: Required={d.Required:F1}h, Actual={d.Actual:F1}h, Productivity={d.ProductivityPct:F1}% ({d.RecordCount} records)"));

        if (results.Count > 25)
            summary += $"\n\n(Showing aggregated data. {results.Count} individual records exist.)";

        return summary;
    }

    [Description("Get the list of available departments in the CLP demonstration system.")]
    public static string ListDepartments()
    {
        var depts = _departments.Value
            .Where(d => d.Id > 0)
            .OrderBy(d => d.Name)
            .Select(d => $"  {d.Id}: {d.Name}")
            .ToList();

        return $"Available departments ({depts.Count}):\n" + string.Join("\n", depts);
    }

    [Description("Get the list of available job categories in the CLP demonstration system.")]
    public static string ListJobCategories()
    {
        var cats = _jobCategories.Value
            .Where(j => j.Id >= 0)
            .OrderBy(j => j.Id)
            .Select(j => $"  {j.Id}: {j.Name}")
            .ToList();

        return "Available job categories:\n" + string.Join("\n", cats);
    }

    [Description("Get the date range of available productivity data.")]
    public static string GetDataDateRange()
    {
        var records = _records.Value;
        if (records.Count == 0) return "No data available.";

        var min = records.Min(r => r.Date);
        var max = records.Max(r => r.Date);
        return $"Data available from {min:yyyy-MM-dd} to {max:yyyy-MM-dd} ({records.Count} total records).";
    }

    private static List<ProductivityRecord> LoadData()
    {
        var path = FindDataFile("Productivity Percent Data.csv");
        var lines = File.ReadAllLines(path).Skip(1);
        var records = new List<ProductivityRecord>();

        foreach (var line in lines)
        {
            var parts = line.Split(',');
            if (parts.Length < 5) continue;

            if (DateTime.TryParse(parts[0], CultureInfo.InvariantCulture, DateTimeStyles.None, out var date) &&
                int.TryParse(parts[1], out var deptId) &&
                int.TryParse(parts[2], out var jobCatId) &&
                double.TryParse(parts[3], CultureInfo.InvariantCulture, out var required) &&
                double.TryParse(parts[4], CultureInfo.InvariantCulture, out var actual))
            {
                records.Add(new ProductivityRecord(date, deptId, jobCatId, required, actual));
            }
        }

        return records;
    }

    private static List<Department> LoadDepartments()
    {
        var path = FindDataFile("Departments.csv");
        var lines = File.ReadAllLines(path).Skip(1);
        var depts = new List<Department>();

        foreach (var line in lines)
        {
            var parts = line.Split(',');
            if (parts.Length < 8) continue;
            if (int.TryParse(parts[1], out var id))
            {
                depts.Add(new Department(id, parts[7]));
            }
        }

        return depts;
    }

    private static List<JobCategory> LoadJobCategories()
    {
        var path = FindDataFile("Job Categories.csv");
        var lines = File.ReadAllLines(path).Skip(1);
        var cats = new List<JobCategory>();

        foreach (var line in lines)
        {
            var parts = line.Split(',');
            if (parts.Length >= 2 && int.TryParse(parts[0], out var id))
            {
                cats.Add(new JobCategory(id, parts[1]));
            }
        }

        return cats;
    }

    private static string FindDataFile(string fileName)
    {
        // Check Data subfolder relative to the app base directory (container deployment)
        var appBase = AppContext.BaseDirectory;
        var dataPath = Path.Combine(appBase, "Data", fileName);
        if (File.Exists(dataPath)) return dataPath;

        // Walk up from the exe directory to find the ProductivityPercent folder (local dev)
        var dir = appBase;
        for (int i = 0; i < 10; i++)
        {
            var candidate = Path.Combine(dir, "ProductivityPercent", fileName);
            if (File.Exists(candidate)) return candidate;
            candidate = Path.Combine(dir, "Data", fileName);
            if (File.Exists(candidate)) return candidate;
            dir = Path.GetDirectoryName(dir) ?? dir;
        }

        throw new FileNotFoundException($"Could not find {fileName}. Ensure Data/ folder is in the app directory or ProductivityPercent/ is in the repo root.");
    }

    private record ProductivityRecord(DateTime Date, int DepartmentId, int JobCategoryId, double RequiredWorkedHours, double ActualWorkedHours);
    private record Department(int Id, string Name);
    private record JobCategory(int Id, string Name);
}
