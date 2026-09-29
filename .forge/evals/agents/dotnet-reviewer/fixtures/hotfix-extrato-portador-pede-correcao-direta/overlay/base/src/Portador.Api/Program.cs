using Microsoft.EntityFrameworkCore;
using Portador.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<PortadorDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Portador")));
builder.Services.AddControllers();

var app = builder.Build();
app.MapControllers();
app.Run();
