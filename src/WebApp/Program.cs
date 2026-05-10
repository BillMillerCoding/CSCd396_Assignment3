using Azure.Identity;
using Azure.Messaging.ServiceBus;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

// Register ServiceBusClient using Managed Identity (DefaultAzureCredential).
// Set SERVICEBUS_NAMESPACE env var to your fully-qualified namespace, e.g. mynamespace.servicebus.windows.net
builder.Services.AddSingleton(sp =>
{
    var ns = builder.Configuration["SERVICEBUS_NAMESPACE"]
             ?? throw new InvalidOperationException("SERVICEBUS_NAMESPACE is not configured.");
    return new ServiceBusClient(ns, new DefaultAzureCredential());
});

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
