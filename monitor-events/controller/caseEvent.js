const router = require('express').Router();
const AppError = require('../common/appError');
const EventUtility = require('../common/event');
const path = require('path');
router.get('/dash/', function (req, res) {
    try {
        res.sendFile(path.join(__dirname, '../view/CaseEvent.html'));
    } catch (err) {
        new AppError(err, 'Failed to load Case Event Page.');
    }
});

router.post('/case', async function(req, res){
    try{
        const result = await EventUtility.postCaseEvent(req.body);
        res.send(result);
    } catch (err) {
        new AppError(err, 'Failed to Submit Case Event.');
    }
});
module.exports = router;