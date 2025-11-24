from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import uvicorn

app = FastAPI(title="Sample API", version="1.0.0")

# CORS設定（開発環境用）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Item(BaseModel):
    id: int
    name: str
    description: str


# サンプルデータ
items_db = [
    {"id": 1, "name": "Item 1", "description": "This is item 1"},
    {"id": 2, "name": "Item 2", "description": "This is item 2"},
    {"id": 3, "name": "Item 3", "description": "This is item 3"},
]


@app.get("/")
async def root():
    return {"message": "Welcome to FastAPI Backend"}


@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "service": "backend"}


@app.get("/api/items", response_model=List[Item])
async def get_items():
    return items_db


@app.get("/api/items/{item_id}", response_model=Item)
async def get_item(item_id: int):
    for item in items_db:
        if item["id"] == item_id:
            return item
    return {"error": "Item not found"}


@app.post("/api/items", response_model=Item)
async def create_item(item: Item):
    items_db.append(item.dict())
    return item


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
