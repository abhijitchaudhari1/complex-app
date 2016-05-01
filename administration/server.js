const express = require('express');
const redis = require('redis');
const request = require('request');
const MongoClient = require('mongodb').MongoClient

// Constants
const PORT = 8080;

// Test Redis connection
const redisClient = redis.createClient({ host: 'redis' });
redisClient.on("error", function (err) {
    console.log("Error " + err);
});

// Test MongoDB connection
MongoClient.connect('mongodb://mongodb:27017/test', function(err, db) {
  if (err) {
    console.log(err);
    return;
  }
  
  console.log("Connected correctly to MongoDB");
  db.close();
});

// Test connection to API server
const app = express();
app.get('/', (req, res) => {
  request('http://api:8080/', function (error, response, body) {
  if (!error && response.statusCode == 200) {
    res.send(`Response from API server: ${body}`);
  } else {
    console.log(error);
    res.send('Error');
  }
})
});

app.listen(PORT);
console.log('Administration running on http://127.0.0.1:' + PORT);