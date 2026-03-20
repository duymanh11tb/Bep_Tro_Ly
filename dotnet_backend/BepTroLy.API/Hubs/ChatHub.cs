using Microsoft.AspNetCore.SignalR;
using BepTroLy.API.Models;
using BepTroLy.API.Data;
using Microsoft.EntityFrameworkCore;

namespace BepTroLy.API.Hubs;

public class ChatHub : Hub
{
    private readonly AppDbContext _db;

    public ChatHub(AppDbContext db)
    {
        _db = db;
    }

    public async Task JoinFridgeGroup(int fridgeId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"fridge_{fridgeId}");
    }

    public async Task LeaveFridgeGroup(int fridgeId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"fridge_{fridgeId}");
    }

    public async Task SendMessage(int fridgeId, string content)
    {
        var userIdString = Context.User?.FindFirst("user_id")?.Value;
        if (string.IsNullOrEmpty(userIdString)) return;
        
        int userId = int.Parse(userIdString);
        
        // Save to DB
        var message = new ChatMessage
        {
            FridgeId = fridgeId,
            UserId = userId,
            Content = content,
            CreatedAt = DateTime.UtcNow
        };
        
        _db.ChatMessages.Add(message);
        await _db.SaveChangesAsync();
        
        // Fetch User for display info
        var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserId == userId);
        
        await Clients.Group($"fridge_{fridgeId}").SendAsync("ReceiveMessage", new {
            message_id = message.MessageId,
            fridge_id = fridgeId,
            user_id = userId,
            display_name = user?.DisplayName ?? "Unknown",
            photo_url = user?.PhotoUrl,
            content = content,
            created_at = message.CreatedAt
        });
    }
}
