// ============================================================================
// CLP Multi-Agent Hosted Agent — Microsoft Foundry Agent Service
// ============================================================================
// Hosted agent deployment of the Contoso Labour Productivity orchestrator.
// Uses the Agent Framework (Microsoft.Agents.AI) with Foundry hosting.
// Pattern: Orchestrator agent routes to domain sub-agents exposed as function tools.
// ============================================================================

using Azure.AI.AgentServer.Core;
using Azure.AI.Projects;
using Azure.Identity;
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Foundry.Hosting;
using Microsoft.Extensions.AI;
using ClpHostedAgent.Tools;

if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")))
{
    Console.Error.WriteLine(
        "[WARNING] APPLICATIONINSIGHTS_CONNECTION_STRING not set — traces will not be sent " +
        "to Application Insights. Set it to enable local telemetry. " +
        "(This variable is auto-injected in hosted Foundry containers.)");
}

var projectEndpoint = new Uri(Environment.GetEnvironmentVariable("FOUNDRY_PROJECT_ENDPOINT")
    ?? throw new InvalidOperationException("FOUNDRY_PROJECT_ENDPOINT environment variable is not set."));

var deployment = Environment.GetEnvironmentVariable("AZURE_AI_MODEL_DEPLOYMENT_NAME")
    ?? throw new InvalidOperationException("AZURE_AI_MODEL_DEPLOYMENT_NAME environment variable is not set.");

var client = new AIProjectClient(projectEndpoint, new DefaultAzureCredential());

// --- Sub-Agent 1: Productivity Data Agent (simulates Fabric Data Agent) ---
AIAgent productivityAgent = client.AsAIAgent(
    model: deployment,
    instructions: """
        You are the Productivity Percent Data Agent for the Contoso Labour Productivity (CLP) demonstration system.
        You answer questions about productivity percent data from the CLP data store.

        Key rules:
        - Productivity Percent = Required Worked Hours / Actual Worked Hours × 100
        - Always show the Required and Actual values used to calculate productivity
        - When a user doesn't specify a time range, inform them results are for all available time
        - Use partial matching for department names (users may not use full names)
        - If results exceed 25 records, state that additional data exists

        You have access to tools to query the productivity data, list departments,
        list job categories, and get the available date range.
        """,
    name: "ProductivityDataAgent",
    description: "Answers questions about productivity percent data — staffing efficiency metrics by department, job category, and date range. Simulates a Fabric Data Agent querying the CLP data store.",
    tools:
    [
        AIFunctionFactory.Create(ProductivityDataTools.QueryProductivityData),
        AIFunctionFactory.Create(ProductivityDataTools.ListDepartments),
        AIFunctionFactory.Create(ProductivityDataTools.ListJobCategories),
        AIFunctionFactory.Create(ProductivityDataTools.GetDataDateRange),
    ]);

// --- Sub-Agent 2: General Knowledge Agent (simulates RAG over User Guide) ---
AIAgent generalAgent = client.AsAIAgent(
    model: deployment,
    instructions: """
        You are the General Knowledge Agent for the Contoso Labour Productivity (CLP) demonstration system.
        You answer conceptual questions about CLP — what things mean, how calculations work,
        and general product knowledge. You do NOT query actual data.

        If a user asks for actual data values, tell them you only handle conceptual questions
        and suggest they ask about the data directly (which will route to the data agent).
        """,
    name: "GeneralKnowledgeAgent",
    description: "Answers conceptual questions about CLP — definitions, how calculations work, what terms mean. Does NOT query actual data values.",
    tools:
    [
        AIFunctionFactory.Create(GeneralKnowledgeTools.LookupClpConcept),
        AIFunctionFactory.Create(GeneralKnowledgeTools.GetProductivityCalculationHelp),
    ]);

// --- Orchestrator Agent: Routes queries to the appropriate sub-agent ---
AIAgent orchestrator = client.AsAIAgent(
    model: deployment,
    instructions: """
        You are the CLP (Contoso Labour Productivity) Orchestrator Agent.
        You help hospital staff understand their staffing productivity.

        You have two specialist agents available as tools:
        1. ProductivityDataAgent — call this for ANY question about actual data values,
           metrics, numbers, trends, comparisons between departments, date-specific queries.
        2. GeneralKnowledgeAgent — call this for conceptual questions like "what is productivity percent",
           "how is it calculated", "what does CLP stand for", definitions, explanations.

        Routing rules:
        - If the user asks for data → ProductivityDataAgent
        - If the user asks what something means → GeneralKnowledgeAgent
        - If unclear, ask a brief clarifying question
        - Always pass the user's full question to the sub-agent
        - Present the sub-agent's response clearly to the user
        - You may add brief context but don't alter the data

        Keep responses professional and concise.
        """,
    name: "ClpOrchestrator",
    description: "Top-level orchestrator that routes CLP questions to specialist agents.",
    tools:
    [
        productivityAgent.AsAIFunction(),
        generalAgent.AsAIFunction(),
    ]);

// --- Host the orchestrator as a Foundry Responses agent ---
var builder = AgentHost.CreateBuilder(args);
builder.Services.AddFoundryResponses(orchestrator);
builder.RegisterProtocol("responses", endpoints => endpoints.MapFoundryResponses());

var app = builder.Build();
app.Run();
