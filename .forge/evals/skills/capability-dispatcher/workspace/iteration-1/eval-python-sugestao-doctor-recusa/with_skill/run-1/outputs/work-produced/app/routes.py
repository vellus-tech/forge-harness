from flask import Blueprint, abort, jsonify

from app.db import connect

bp = Blueprint("vehicles", __name__)


@bp.get("/vehicles/<plate>")
def get_vehicle(plate: str):
    with connect() as conn:
        row = conn.execute("SELECT plate, operator_id, capacity FROM vehicles WHERE plate = %s", (plate,)).fetchone()
    if row is None:
        abort(404)
    return jsonify({"plate": row[0], "operator_id": row[1], "capacity": row[2]})
