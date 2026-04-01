from fastapi import FastAPI

app = FastAPI()

# changed

@app.get("/")
def read_root():
    return {"message": "Hello, Cloud Native!"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
