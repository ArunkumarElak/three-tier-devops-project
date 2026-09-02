require("dotenv").config();
const express = require("express");
const cors = require("cors");

const app = express();

var corsOptions = {
  origin: process.env.CLIENT_ORIGIN || "http://localhost:8081"
};

app.use(cors(corsOptions));

// parse requests of content-type - application/json
app.use(express.json());

// parse requests of content-type - application/x-www-form-urlencoded
app.use(express.urlencoded({ extended: true }));

const db = require("./app/models");

// Retry the initial schema sync: the MySQL container may still be
// initializing when the API starts, even after the compose healthcheck.
function syncWithRetry(retries, delayMs) {
  db.sequelize
    .sync()
    .then(() => console.log("Database synced."))
    .catch((err) => {
      if (retries <= 0) {
        console.error("Unable to sync database:", err.message);
        process.exit(1);
      }
      console.log(`DB not ready (${err.message}), retrying in ${delayMs}ms...`);
      setTimeout(() => syncWithRetry(retries - 1, delayMs), delayMs);
    });
}
syncWithRetry(10, 3000);

// simple route
app.get("/", (req, res) => {
  res.json({ message: "Welcome to bezkoder application." });
});

require("./app/routes/turorial.routes")(app);

// set port, listen for requests
const PORT = process.env.NODE_DOCKER_PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}.`);
});
