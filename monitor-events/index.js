const express = require('express');
const app = express();
const dotEnv = require('dotenv');
const bodyParser = require('body-parser');

dotEnv.config();

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({
    extended : true
}));

app.get('/',(req,res) => {
    res.redirect('./event/dash');
});
app.get('/',(req,res) => {
    res.redirect('./caseevent/dash');
});
//add routes here
app.use(express.static(__dirname + '/public'));
app.use('/event',require('./controller/event'));
app.use('/caseevent',require('./controller/caseEvent'));

app.listen(process.env.PORT,()=>{console.clear(); console.log('Server is now running... Listening on port: ' + process.env.PORT);});
