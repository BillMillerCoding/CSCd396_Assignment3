using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FunctionApp;

public class ServiceBusMessageFunction
{
    private readonly ILogger<ServiceBusMessageFunction> _logger;

    public ServiceBusMessageFunction(ILogger<ServiceBusMessageFunction> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Triggered by a Service Bus message. Writes the message body to an Azure Blob Storage container.
    /// Requires the following application settings / environment variables:
    ///   STORAGE_ACCOUNT_NAME  - name of the Azure Storage Account (e.g. "mystorageaccount")
    ///   STORAGE_CONTAINER_NAME - name of the blob container (e.g. "messages")
    /// Authentication to Storage is performed via Managed Identity (DefaultAzureCredential).
    /// </summary>
    [Function("ServiceBusMessageFunction")]
    public async Task Run(
        [ServiceBusTrigger("%SERVICEBUS_QUEUE_NAME%", Connection = "ServiceBusConnection")] string messageBody,
        FunctionContext context)
    {
        _logger.LogInformation("Received Service Bus message: {MessageBody}", messageBody);

        var storageAccountName = Environment.GetEnvironmentVariable("STORAGE_ACCOUNT_NAME")
            ?? throw new InvalidOperationException("STORAGE_ACCOUNT_NAME is not configured.");
        var containerName = Environment.GetEnvironmentVariable("STORAGE_CONTAINER_NAME")
            ?? "messages";

        var blobServiceUri = new Uri($"https://{storageAccountName}.blob.core.windows.net");
        var blobServiceClient = new BlobServiceClient(blobServiceUri, new DefaultAzureCredential());

        var containerClient = blobServiceClient.GetBlobContainerClient(containerName);
        await containerClient.CreateIfNotExistsAsync();

        // Use a timestamp-based blob name to avoid collisions
        var blobName = $"{DateTime.UtcNow:yyyyMMddHHmmssfff}_{Guid.NewGuid():N}.txt";
        var blobClient = containerClient.GetBlobClient(blobName);

        using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(messageBody));
        await blobClient.UploadAsync(stream, overwrite: false);

        _logger.LogInformation("Message written to blob: {BlobName}", blobName);
    }
}
