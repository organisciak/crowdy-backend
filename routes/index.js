var express = require('express');
var router = express.Router();

/* GET home page. */
router.get('/', function(req, res, next) {
  res.render('index', { title: 'Express' });
});


// Send JSON to /json
router.get('/json', function(req, res) {
  sampleObject = { "name": "P", 3:true };
  res.jsonp(sampleObject);
});



module.exports = router;
