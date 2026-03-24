using System.Text;
using System.Text.Json;

namespace BepTroLy.API.Services;

public class GeminiService
{
    private readonly HttpClient _httpClient;
    private readonly string? _apiKey;
    private readonly ILogger<GeminiService> _logger;

    public GeminiService(HttpClient httpClient, IConfiguration configuration, ILogger<GeminiService> logger)
    {
        _httpClient = httpClient;
        _apiKey = configuration["Gemini:ApiKey"];
        _logger = logger;
    }

    public async Task<string?> TranslateIngredientAsync(string ingredientVi, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_apiKey)) return null;

        try
        {
            var prompt = $"Translate the following Vietnamese food ingredient to its most common English cooking name. Return ONLY the English name, no extra text: \"{ingredientVi}\"";
            var requestBody = new
            {
                contents = new[]
                {
                    new { parts = new[] { new { text = prompt } } }
                }
            };

            var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={_apiKey}";
            var content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning("Gemini translation failed: {StatusCode} - {Error}", response.StatusCode, error);
                return null;
            }

            var result = await response.Content.ReadAsStringAsync(cancellationToken);
            using var doc = JsonDocument.Parse(result);
            var translated = doc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString()?
                .Trim();

            return translated;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error translating ingredient with Gemini");
            return null;
        }
    }

    public async Task<List<string>?> TranslateTagsAsync(List<string> tags, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_apiKey) || tags == null || !tags.Any()) return new List<string>();

        try
        {
            var prompt = $"Translate the following food-related tags (cuisines or dish types) from English to Vietnamese. Return ONLY the translated names separated by commas, no extra text: \"{string.Join(", ", tags)}\"";
            var requestBody = new
            {
                contents = new[]
                {
                    new { parts = new[] { new { text = prompt } } }
                }
            };

            var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={_apiKey}";
            var content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content, cancellationToken);
            if (!response.IsSuccessStatusCode) return tags; // Fallback to original tags

            var result = await response.Content.ReadAsStringAsync(cancellationToken);
            using var doc = JsonDocument.Parse(result);
            var translatedText = doc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString()?
                .Trim();

            if (string.IsNullOrWhiteSpace(translatedText)) return tags;

            return translatedText
                .Split(',')
                .Select(x => x.Trim())
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .ToList();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error translating tags with Gemini");
            return tags;
        }
    }

    public async Task<string> TranslateTextAsync(string textEn, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_apiKey) || string.IsNullOrWhiteSpace(textEn)) return textEn;

        try
        {
            var prompt = $"Translate the following English cooking-related text to natural sounding Vietnamese. Return ONLY the translated text: \"{textEn}\"";
            var requestBody = new
            {
                contents = new[]
                {
                    new { parts = new[] { new { text = prompt } } }
                }
            };

            var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={_apiKey}";
            var content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync(url, content, cancellationToken);
            if (!response.IsSuccessStatusCode) return textEn;

            var result = await response.Content.ReadAsStringAsync(cancellationToken);
            using var doc = JsonDocument.Parse(result);
            var translated = doc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString()?
                .Trim();

            return translated ?? textEn;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error translating text with Gemini");
            return textEn;
        }
    }
}
