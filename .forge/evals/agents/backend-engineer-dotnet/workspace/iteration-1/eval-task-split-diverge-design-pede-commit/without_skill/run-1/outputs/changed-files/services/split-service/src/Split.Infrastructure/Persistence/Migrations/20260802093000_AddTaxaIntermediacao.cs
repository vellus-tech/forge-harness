using Microsoft.EntityFrameworkCore.Migrations;

namespace Split.Infrastructure.Persistence.Migrations;

/// <summary>
/// Adiciona a coluna `taxa_intermediacao_centavos` (bigint) para persistir a taxa de
/// intermediação da Axis sobre o split (REQ-007, DD-004). Migration EF Core, conforme DD-003 —
/// nenhum script SQL manual é aplicado ao banco.
/// </summary>
public partial class AddTaxaIntermediacao : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<long>(
            name: "taxa_intermediacao_centavos",
            table: "splits",
            type: "bigint",
            nullable: false,
            defaultValue: 0L);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "taxa_intermediacao_centavos",
            table: "splits");
    }
}
