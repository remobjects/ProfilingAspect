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
			Test2(5);
			return 0;
		}

		private static void Test2(int n)
		{
			if (n == 0)
				Test3();
			else
				Test2(n - 1);
		}

		private static void Test3() 
		{
			System.Threading.Thread.Sleep(100);
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
