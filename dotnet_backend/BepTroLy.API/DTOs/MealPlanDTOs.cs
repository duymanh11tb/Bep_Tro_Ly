using System.Text.Json;

namespace BepTroLy.API.DTOs;

public class UpsertMealPlanRequest
{
    public JsonElement PlanData { get; set; }
}
