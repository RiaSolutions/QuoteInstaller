using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Quote.Update
{
    internal class Writer
    {
        public string Filepath { get; private set; }
        private static object locker = new Object();

        public Writer(string filepath)
        {
            Filepath = filepath;
        }

        public void WriteToFile(string text)
        {
            try
            {
                lock (locker)
                {
                    using (FileStream file = new FileStream(Filepath, FileMode.Append, FileAccess.Write, FileShare.Read))
                    {
                        using (StreamWriter writer = new StreamWriter(file, Encoding.Unicode))
                        {
                            writer.WriteLine(text);
                        }
                    }
                }
            }
            catch(Exception)
            {
                //ignore
            }

        }
    }
}
