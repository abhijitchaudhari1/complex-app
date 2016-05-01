const express = require('express');
const redis = require("redis");
const MongoClient = require('mongodb').MongoClient

const PORT = 8080;

// Test connection to Redis
const redisClient = redis.createClient({ host: 'redis' });
redisClient.on("error", function (err) {
    console.log("Error " + err);
});

// Test connection to MongoDB
MongoClient.connect('mongodb://mongodb:27017/test', function(err, db) {
  if (err) {
    console.log(err);
    return;
  }
  
  console.log("Connected correctly to MongoDB");
  db.close();
});

// Save and load data from Redis
const app = express();
app.get('/', (req, res) => {
  const str = 'Welcome to API server';
  const uid = `welcome-${Date.now()}`;
  redisClient.set(uid, str);
  redisClient.get(uid, (err, reply) => {
    if (err) {
      console.log(err);
      res.send('Error');
      return;
    }
    
    res.send(`[redis][${uid}]=> ${reply.toString()}`);
  });
});

app.listen(PORT);
console.log('API server running on http://127.0.0.1:' + PORT);