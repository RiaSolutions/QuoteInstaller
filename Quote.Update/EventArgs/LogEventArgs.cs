using System;

namespace Quote.Update
{
    /// <summary>
    /// Class LogEventArgs.
    /// </summary>
    public class LogEventArgs : EventArgs
    {
        #region Constructor

        /// <summary>
        /// Initializes a new instance of the <see cref="LogEventArgs"/> class.
        /// </summary>
        /// <param name="message">The message.</param>
        public LogEventArgs (string message)
        {
            Message = message;
        }

        #endregion


        #region Proprties

        /// <summary>
        /// Gets the message.
        /// </summary>
        /// <value>The message.</value>
        public string Message { get; private set; }

        #endregion
    }
}
