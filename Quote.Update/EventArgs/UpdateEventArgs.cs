using System;

namespace Quote.Update
{
    public class UpdateEventArgs : EventArgs
    {
        #region Constructor

        public UpdateEventArgs(string message)
        {
            Message = message;
            ShouldUpdate = false;
        }

        #endregion


        #region Proprties

        public string Message { get; private set; }

        public bool ShouldUpdate { get; set; }

        #endregion
    }
}
