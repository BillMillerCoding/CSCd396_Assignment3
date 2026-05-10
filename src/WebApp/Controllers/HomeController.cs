using Azure.Messaging.ServiceBus;
using Microsoft.AspNetCore.Mvc;
using WebApp.Models;

namespace WebApp.Controllers;

public class HomeController : Controller
{
    private readonly ServiceBusClient _serviceBusClient;
    private readonly IConfiguration _configuration;

    public HomeController(ServiceBusClient serviceBusClient, IConfiguration configuration)
    {
        _serviceBusClient = serviceBusClient;
        _configuration = configuration;
    }

    [HttpGet]
    public IActionResult Index()
    {
        return View(new MessageModel());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SendMessage(MessageModel model)
    {
        if (!ModelState.IsValid || string.IsNullOrWhiteSpace(model.MessageText))
        {
            model.StatusMessage = "Please enter a message.";
            return View("Index", model);
        }

        var queueName = _configuration["SERVICEBUS_QUEUE_NAME"]
                        ?? throw new InvalidOperationException("SERVICEBUS_QUEUE_NAME is not configured.");

        await using var sender = _serviceBusClient.CreateSender(queueName);
        await sender.SendMessageAsync(new ServiceBusMessage(model.MessageText));

        model.StatusMessage = $"Message sent successfully: \"{model.MessageText}\"";
        model.MessageText = string.Empty;
        return View("Index", model);
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View();
    }
}
