import Foundation

// The fundamental unit for creating an asynchronous context is known as Task, and it can be created in a way similar to threads and dispatch work items:
// let task: Task<(), Never> // generic over two types.
// The first is the type of value that will be produced from the task after the asynchronous work is finished.
// Right now it’s void to represent that it doesn’t produce anything of interest. And the second generic is the type of error that can thrown inside the closure. Since Swift does not support typed throws (yet) this generic will always be either Never to represent it cannot fail, or Error to represent that any kind of error can be throw.
//let task = Task {
//  print(Thread.current) // prints a new thread, and is not the main thread
//}

// type has changed to let task: Task<Int, Never>
//let task = Task {
//  42
//}

let task = Task<Int, Error>.init {
  struct SomeError: Error { }
  throw SomeError()
  return 42
}

// let's look at the Task init() method.
//public init(priority: TaskPriority? = nil, operation: @escaping @Sendable () async throws -> Success)

func doSomethingAsync() async {}

// trying to invoke a function marked with async throws a compiler error.
// 🛑 'async' call in a function that does not support concurrency
// this is because where we're calling it is not an asynchronous context.
// doSomethingAsync()

// we can wrap it in a `Task { }` to introduce an async context.
// and we would have to use the await keyword in front of the call.
// the Task.init() introduces a brand new async context to work in and then executes our async closure in that context.
Task {
  // the use of await here creates something known as a suspension point.
  await doSomethingAsync()
}

// we can call out async functions from other async functions
// notice that we're getting compile time distinction between asynchronous code and synchronous code.
func doSomethingElseAsync() async {
  await doSomethingAsync()
}

// It’s worth mentioning that decorating functions with these little keywords can be thought of as a sugar-fied version of a function that returns tasks and results. For example, a throwing function like this:
// (A) throws -> B
// Can be thought of as a function that drops the throws keyword and just returns a result instead:
// (A) -> Result<B, Error>
// Learn more about these patterns in the episodes transcript.

// (inout A) -> B
// (A) -> (B, A)

// (A) async -> B // sugard version
// (A) -> Task<B, Never> // unsugared version
// (A) -> ((B) -> Void) -> Void // curried version
// (A, (B) -> Void) -> Void // uncurried version. this is the fundamental shape of a completion handler.

// most of Apple's asynchronous APIs have this shape
// dataTask: (URL, completionHandler: (Data?, Response?, Error?) -> Void) -> Void
// start: ((MKLocalSearch.Response?, Error?) -> Void) -> Void

Thread.sleep(forTimeInterval: 2)
