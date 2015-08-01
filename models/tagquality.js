var mongoose = require('mongoose');

var tagQualitySchema = mongoose.Schema({
    item_id: Number,
    tag: String,
    // 0 = too hard, 1 = poor, 2 = okay, 3 = good, 4 = great
    quality: String
});

var TagQuality = mongoose.connection.model('TagQuality', tagQualitySchema);

module.exports = TagQuality; 
