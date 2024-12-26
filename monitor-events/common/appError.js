/*
  @author: Amin ur Rehman (GitHub: AminSays)
  @version: 1.0
  @name: AppError
  @description: Custom error handler for error handling and formatted logging
*/
class AppError extends Error
{
  /*
    @name: constructor
    @description: Default constructor to create AppError and log error details
    @param: Error default/custom to be handled 
    @param: Custom/Friendly error message
    @return: AppError
  */
    constructor(err, msg){
      super(msg);
      if(err.constructor.name != 'AppError') { //already logged
        console.log(err.constructor.name + ': ' + err.message + '. ' + (err.hint == undefined ? '' : err.hint));
        //console.log(err);
      }

    }
}

module.exports = AppError;