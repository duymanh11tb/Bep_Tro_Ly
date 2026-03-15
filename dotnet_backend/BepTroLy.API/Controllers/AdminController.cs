using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BepTroLy.API.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "admin")]
public class AdminController : ControllerBase
{
    [HttpGet("test")]
    public IActionResult TestAdmin()
    {
        return Ok(new { message = "You have admin access!", timestamp = DateTime.UtcNow });
    }
}
