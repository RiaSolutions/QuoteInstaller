using System;
using System.IO;
using System.Linq;
using System.Xml.Linq;

namespace Quote.Update
{
    internal class Manifest
    {
        #region Fields

        private string _data;

        #endregion


        #region Constructor

        /// <summary>
        /// Initializes a new instance of the <see cref="Manifest"/> class.
        /// </summary>
        /// <param name="data">The data.</param>
        public Manifest(string data)
        {
            Load(data);
        }

        #endregion


        #region Properties

        /// <summary>
        /// Gets the version.
        /// </summary>
        /// <value>The version.</value>
        public Version Version { get; private set; }

        /// <summary>
        /// Gets the check interval.
        /// </summary>
        /// <value>The check interval.</value>
        public int CheckInterval { get; private set; }

        /// <summary>
        /// Gets the remote configuration URI.
        /// </summary>
        /// <value>The remote configuration URI.</value>
        public string RemoteConfigUri { get; private set; }

        /// <summary>
        /// Gets the security token.
        /// </summary>
        /// <value>The security token.</value>
        public string SecurityToken { get; private set; }

        /// <summary>
        /// Gets the base URI.
        /// </summary>
        /// <value>The base URI.</value>
        public string BaseUri { get; private set; }

        /// <summary>
        /// Gets the payload.
        /// </summary>
        /// <value>The payload.</value>
        public string Payload { get; private set; }

        #endregion


        #region Methods

        /// <summary>
        /// Loads the specified data.
        /// </summary>
        /// <param name="data">The data.</param>
        private void Load (string data)
        {
            _data = data;
            try
            {
                Log.Write("{0} started.", MethodInfoHelper.GetCurrentMethodName());

                // Load config from XML
                var xml = XDocument.Parse(data);
                if (xml.Root.Name.LocalName != "Manifest")
                {
                    Log.Write("Root XML element '{0}' is not recognized, stopping.", xml.Root.Name);
                    return;
                }

                // Set properties.
                Version = ParseVersion(xml.Root.Attribute("version").Value);
                CheckInterval = int.Parse(xml.Root.Element("CheckInterval").Value);
                SecurityToken = xml.Root.Element("SecurityToken").Value;
                RemoteConfigUri = xml.Root.Element("RemoteConfigUri").Value;
                BaseUri = xml.Root.Element("BaseUri").Value;
                Payload = xml.Root.Element("Payload").Value;
            }
            catch (Exception ex)
            {
                Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
            }
            finally
            {
                Log.Write("{0} ended.", MethodInfoHelper.GetCurrentMethodName());
            }
        }

        private Version ParseVersion(string input)
        {
            Version version = null;
            Version.TryParse(input, out version);
            return version;  
        }


        #endregion
    }
}
