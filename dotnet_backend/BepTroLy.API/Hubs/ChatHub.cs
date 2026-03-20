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
        var groupName = $"fridge_{fridgeId}";
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
        Console.WriteLine($"[CHAT] Connection {Context.ConnectionId} joined group {groupName}");
    }

    public async Task LeaveFridgeGroup(int fridgeId)
    {
        var groupName = $"fridge_{fridgeId}";
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
        Console.WriteLine($"[CHAT] Connection {Context.ConnectionId} left group {groupName}");
    }

    public async Task SendMessage(int fridgeId, string content)
    {
        var userIdString = Context.User?.FindFirst("user_id")?.Value;
        if (string.IsNullOrEmpty(userIdString))
        {
            Console.WriteLine($"[CHAT] SendMessage failed: User NOT authenticated for connection {Context.ConnectionId}");
            return;
        }
        
        int userId = int.Parse(userIdString);
        Console.WriteLine($"[CHAT] User {userId} sending message to fridge {fridgeId}: {content}");
        
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
        
        var broadcastData = new {
            message_id = message.MessageId,
            fridge_id = fridgeId,
            user_id = userId,
            display_name = user?.DisplayName ?? "Unknown",
            photo_url = user?.PhotoUrl,
            content = content,
            created_at = message.CreatedAt
        };

        var groupName = $"fridge_{fridgeId}";
        await Clients.Group(groupName).SendAsync("ReceiveMessage", broadcastData);
        Console.WriteLine($"[CHAT] Message {message.MessageId} broadcasted to {groupName}");

        // Create in-app Notifications for all other members
        try
        {
            var otherMembers = await _db.FridgeMembers
                .Where(m => m.FridgeId == fridgeId && m.UserId != userId && m.Status == "accepted")
                .Select(m => m.UserId)
                .ToListAsync();

            foreach (var memberId in otherMembers)
            {
                var notification = new Notification
                {
                    UserId = memberId,
                    Type = "chat_message",
                    Title = $"Tin nhắn mới từ {user?.DisplayName ?? "Thành viên"}",
                    Body = content.Length > 100 ? content.Substring(0, 97) + "..." : content,
                    RelatedItemId = fridgeId,
                    CreatedAt = DateTime.UtcNow,
                    IsRead = false
                };
                _db.Notifications.Add(notification);
            }
            await _db.SaveChangesAsync();
            Console.WriteLine($"[CHAT] Created in-app notifications for {otherMembers.Count} members");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[CHAT] Error creating in-app notifications: {ex.Message}");
        }
    }
}
