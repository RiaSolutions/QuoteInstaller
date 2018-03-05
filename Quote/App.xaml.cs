using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

using Quote.Update;


namespace Quote
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        private void Application_Startup(object sender, StartupEventArgs e)
        {
            Log.Event += (senderLog, eLog) => MessageBox.Show(eLog.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);

            Updater updater = new Updater();
            updater.StartMonitoring();
            updater.Event += (senderUpdater, eUpdater) => Update(senderUpdater, eUpdater);
        }

        private void Update(object sender, UpdateEventArgs e)
        {
            var messageResponse = MessageBox.Show(e.Message, "Upgrade", MessageBoxButton.OKCancel, MessageBoxImage.Question);
            if (messageResponse == MessageBoxResult.OK)
                e.ShouldUpdate = true;
            else
                e.ShouldUpdate = false;
        }
    }
}
