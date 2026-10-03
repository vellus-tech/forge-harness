using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Split.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddTaxaIntermediacao : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "taxa_intermediacao_centavos",
                table: "splits",
                type: "bigint",
                nullable: false,
                defaultValue: 0L);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "taxa_intermediacao_centavos",
                table: "splits");
        }
    }
}
