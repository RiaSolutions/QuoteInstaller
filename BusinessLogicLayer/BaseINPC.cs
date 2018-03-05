using System.ComponentModel;

namespace BusinessLogicLayer
{
    public abstract class BaseINPC : INotifyPropertyChanged  
    {
        protected void RaisePropertyChanged(string propertyName)
        {
            var handler = PropertyChanged; 

            if (handler != null)
            {
                handler(this, new PropertyChangedEventArgs(propertyName));
            }
        }

        public event PropertyChangedEventHandler PropertyChanged;
    }
}
