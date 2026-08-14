using System.ComponentModel;

namespace ClpHostedAgent.Tools;

public static class GeneralKnowledgeTools
{
    [Description("Look up a CLP (Contoso Labour Productivity) concept or term definition. Use this when users ask 'what is', 'define', 'explain' type questions about CLP concepts.")]
    public static string LookupClpConcept(
        [Description("The CLP concept or term to look up (e.g. 'productivity percent', 'department', 'job category', 'required worked hours')")] string concept)
    {
        var key = concept.ToLowerInvariant().Trim();

        var knowledge = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["productivity percent"] = "Productivity Percent measures how efficiently staff time is being used. It is calculated as: Productivity Percent = Required Worked Hours / Actual Worked Hours × 100. A value of 100% means the department is staffed exactly to requirement. Above 100% indicates understaffing (more work required than hours available). Below 100% indicates overstaffing.",
            ["required worked hours"] = "Required Worked Hours represents the number of hours that should have been worked based on patient volume and acuity. This is derived from staffing standards and workload indicators.",
            ["actual worked hours"] = "Actual Worked Hours represents the number of hours that staff actually worked, as captured from the time and labor system.",
            ["department"] = "A Department in CLP represents an organisational unit within a hospital facility where employee time and labour is captured. Examples include nursing units, emergency services, ICU units, etc.",
            ["job category"] = "A Job Category is a grouping of all job codes. Categories include: RN (Registered Nurse), LPN (Licensed Practical Nurse), Licensed Tech, Management, Other Support, Clinical, and Clerical. These can be updated in the configuration forms.",
            ["acuity level"] = "Acuity Level represents the complexity/severity of patient care needs. Levels range from Minimal (1) through Intermediate (2), Moderate (3), Complex (4), to Intensive (5). Higher acuity requires more staffing hours.",
            ["volume forecast"] = "Volume Forecasts are predictions of future patient volumes used for staffing planning. They are stored in the Fabric Warehouse and can be read/written by the CLP demonstration system.",
            ["staffing plan"] = "A Staffing Plan defines the target staffing levels for a department based on projected patient volumes and acuity. Plans account for skill mix, shift patterns, and productivity targets.",
            ["clp"] = "CLP stands for Contoso Labour Productivity. It is a fictional workforce planning and staffing productivity demonstration for hospitals.",
            ["fabric data agent"] = "A Fabric Data Agent is an AI-powered agent within Microsoft Fabric that can query data in Lakehouses and Warehouses. It generates SQL or DAX queries based on natural language questions and returns structured answers.",
        };

        var match = knowledge.Keys.FirstOrDefault(k => key.Contains(k) || k.Contains(key));
        if (match != null)
            return knowledge[match];

        var partial = knowledge.Keys.FirstOrDefault(k =>
            k.Split(' ').Any(word => key.Contains(word) && word.Length > 3));
        if (partial != null)
            return $"Closest match for '{concept}': {knowledge[partial]}";

        return $"No specific CLP knowledge found for '{concept}'. Available topics include: {string.Join(", ", knowledge.Keys)}.";
    }

    [Description("Get information about how CLP calculates productivity and what factors affect it.")]
    public static string GetProductivityCalculationHelp()
    {
        return """
            Productivity Percent Calculation:
            ================================
            Formula: Productivity % = (Required Worked Hours / Actual Worked Hours) × 100

            Key points:
            - Values can be aggregated across dates, departments, job categories, and acuity levels before applying the formula
            - > 100% indicates the department needed MORE hours than were actually worked (understaffed)
            - < 100% indicates the department needed FEWER hours than were actually worked (overstaffed)
            - = 100% means staffing exactly matched requirements

            The Required Worked Hours are derived from:
            - Patient volume (census/admissions/visits)
            - Acuity level of patients
            - Staffing standards for the department type

            The Actual Worked Hours come from:
            - Time and labor system extracts
            - Includes regular hours, overtime, and agency hours
            """;
    }
}
