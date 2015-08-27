using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using RemObjects.Profiler;

namespace Test
{
	[RemObjects.Profiler.Profile]
	static class Program
	{
		public static Int32 Main(string[] args)
		{
			for (int i = 0; i < 10; i++)
				Test();
			return 0;
		}
		public static void Test() {
			for (int i = 0; i < 15; i++)
				InnerTest();
		}

		public static void InnerTest() 
		{
		System.Threading.Thread.Sleep(15);
		}
	}
}
