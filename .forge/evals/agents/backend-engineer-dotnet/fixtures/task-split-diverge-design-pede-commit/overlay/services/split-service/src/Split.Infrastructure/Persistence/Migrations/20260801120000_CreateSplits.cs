using Microsoft.EntityFrameworkCore.Migrations;

namespace Split.Infrastructure.Persistence.Migrations;

public partial class CreateSplits : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "splits",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false),
                pagamento_id = table.Column<Guid>(type: "uuid", nullable: false),
                recebedor_id = table.Column<Guid>(type: "uuid", nullable: false),
                valor_centavos = table.Column<long>(type: "bigint", nullable: false),
            },
            constraints: table => table.PrimaryKey("pk_splits", x => x.id));
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "splits");
    }
}
