using Amazon.S3;
using Microsoft.EntityFrameworkCore;
using Portador.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<PortadorDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Portador")));
builder.Services.AddSingleton<IAmazonS3>(_ => new AmazonS3Client(Amazon.RegionEndpoint.SAEast1));
builder.Services.AddAuthentication();
builder.Services.AddAuthorization();
builder.Services.AddControllers();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
