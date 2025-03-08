#!/usr/bin/env Rscript

# ---- Load Required Libraries ----
required_packages <- c("jsonlite", "mongolite", "httr", "data.table", "reticulate")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cran.r-project.org")
  }
}

library(jsonlite)
library(mongolite)
library(httr)
library(data.table)
library(reticulate)

# ---- Load FAISS via reticulate ----
use_python("/usr/bin/python3")  # Modify based on your system's Python path
faiss <- import("faiss")

# ---- MongoDB Connection ----
mongo_conn <- mongo(collection = "r_functions", db = "AutoDS", url = "mongodb://localhost:27017")

# ---- Fetch R Functions from MongoDB ----
r_functions <- mongo_conn$find('{}')

if (nrow(r_functions) == 0) {
  cat("No R functions found in MongoDB. Exiting.\n")
  quit()
}

# ---- Extract Descriptions for Embedding ----
get_embedding <- function(text) {
  # OpenAI API Key (ensure to set your API key)
  api_key <- Sys.getenv("OPENAI_API_KEY")
  
  if (api_key == "") {
    stop("Missing OpenAI API Key. Please set OPENAI_API_KEY environment variable.")
  }

  # OpenAI API request
  response <- POST(
    url = "https://api.openai.com/v1/embeddings",
    add_headers(Authorization = paste("Bearer", api_key), `Content-Type` = "application/json"),
    body = toJSON(list(input = text, model = "text-embedding-ada-002"), auto_unbox = TRUE),
    encode = "json"
  )

  result <- content(response, as = "parsed")
  
  if (!is.null(result$errors)) {
    stop("Failed to get embedding: ", result$errors$message)
  }

  return(unlist(result$data[[1]]$embedding))
}

# ---- Generate Embeddings ----
descriptions <- r_functions$description
embeddings <- lapply(descriptions, get_embedding)

# Convert list of embeddings to matrix
embedding_matrix <- do.call(rbind, embeddings)

# ---- Create FAISS Index ----
dim_size <- ncol(embedding_matrix)
index <- faiss$IndexFlatL2(dim_size)
index$add(embedding_matrix)

# ---- Save FAISS Index ----
faiss$write_index(index, "r_function_faiss.index")

cat("FAISS index for R functions saved successfully.\n")
