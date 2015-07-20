var mongoose = require('mongoose');

// Define Schema
var turkBackupSchema = mongoose.Schema({
    _id: String, // The assignmentId
    sandbox: Boolean,
    AssignmentId: String, // Redundant for clarity
    WorkerId: String,
    HITId: String,
    AssignmentStatus: String,
    AutoApprovalTime: Date,
    AcceptTime: Date,
    SubmitTime: Date,
    ApprovalTime: Date,
    Answer: String
});

var TurkBackup = mongoose.connection.model('turkbackup', turkBackupSchema);

module.exports = TurkBackup;
