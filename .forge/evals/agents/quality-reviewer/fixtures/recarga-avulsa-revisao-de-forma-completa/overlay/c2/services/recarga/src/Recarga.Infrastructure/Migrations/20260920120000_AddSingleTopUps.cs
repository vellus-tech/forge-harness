using Microsoft.EntityFrameworkCore.Migrations;

namespace Recarga.Infrastructure.Migrations;

public partial class AddSingleTopUps : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "SingleTopUps",
            columns: table => new
            {
                Id = table.Column<Guid>(name: "Id", nullable: false),
                CardNumber = table.Column<string>(name: "CardNumber", maxLength: 32, nullable: false),
                Amount = table.Column<decimal>(name: "Amount", nullable: false),
                Confirmed = table.Column<bool>(name: "Confirmed", nullable: false)
            },
            constraints: table => table.PrimaryKey("PK_SingleTopUps", x => x.Id));
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "SingleTopUps");
    }
}
