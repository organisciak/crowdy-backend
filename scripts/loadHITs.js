/*
* Load a HIT file from JSON. See data/example-image-hit.json for example.
* JSON needs to be formatting more or less as it goes into Mongo except
* the items.
*/
var mongoose = require('mongoose');
var Hit = require('../models/hit');

// Load JSON from first argument
var path = require('path');
var patharg = process.argv[2];
if (!patharg) return console.error("No file specified.");
var filepath = path.resolve(process.cwd(), patharg);

var inputHIT = require(filepath);
console.log(inputHIT);

mongoose.connect('mongodb://localhost/test');
var db = mongoose.connection;
db.on('error', console.error.bind(console, 'connection error:'));

db.once('open', function onDbOpen(callback) {
    // yay!

    console.log("Connection works!");
    var hit = new Hit(inputHIT);

    hit.save(function(err, res){
        if (err) console.error(err);
        console.log("HIT saved");
        console.log(res);
    });
});
