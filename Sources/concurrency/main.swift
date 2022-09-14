import Foundation

func taskBasics() throws {
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
  
  @Sendable func doSomethingAsync() async {}
  
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
  
  //Task { print("1", Thread.current) }
  //Task { print("2", Thread.current) }
  //Task { print("3", Thread.current) }
  //Task { print("4", Thread.current) }
  //Task { print("5", Thread.current) }
  
  // Just like Threads and OperationQueues, order or thread is non-deterministic
  //5 <NSThread: 0x10130c040>{number = 6, name = (null)}
  //3 <NSThread: 0x1011092f0>{number = 3, name = (null)}
  //2 <NSThread: 0x10070c2f0>{number = 2, name = (null)}
  //1 <NSThread: 0x10107db00>{number = 4, name = (null)}
  //4 <NSThread: 0x1011320d0>{number = 5, name = (null)}
  
  // drastically improves on thread explosion issue with a thread pool compared to  Threads and Queues.
  //for n in 0..<workcount {
  //  Task {
  // this sleep is different from Thread.sleep.
  // it does pause the current task for an amount of time but it does that in a non-blocking manner.
  //    try await Task.sleep(nanoseconds: NSEC_PER_SEC * 1000)
  //    print(n, Thread.current) // only about 10-13 threads were created.
  //  }
  //}
  
  // demo to show that after sleeping a thread (non-blocking),
  // our task can be resumed on any thread, not just the one we started on.
  // care should be taken to not assume that our tasks will resume on the same threads after suspension.
  for n in 0..<workcount {
    Task {
      let current = Thread.current
      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      if current != Thread.current {
        print("Thread changed from", current, "to", Thread.current)
      }
    }
  }
}

// usually the high would be given more priority over the low.
func taskPriority() {
  Task(priority: .low) {
    print("low")
  }
  
  Task(priority: .high) {
    print("high")
  }
}

func taskCancellation() {
  // prints out nil - cause we aren't in any Task context.
  //withUnsafeCurrentTask { task in
  //  print(task)
  //}
  
  // tasks supports cancellation.
  // the print statement still executes event though we cancelled immediately.
  // seems task are kind of more eager if though we cancelled just after creating.
  //let task = Task {
  // Thread.current.isCancelled
  
  // Task.current not available
  // but there is still a way to get the current Task.
  // we're handed the current task in this closure.
  //  withUnsafeCurrentTask { task in
  // print(task) // prints out Optional(Swift.UnsafeCurrentTask(_task: (Opaque Value)))
  //  }
  
  // `isCancelled` magically figures out the current local context.
  //  guard !Task.isCancelled else {
  //    print("Cancelled!")
  // TODO: short-circuit the rest of the work in the task
  // clean up some resources here
  //    return
  //  }
  //  print(Thread.current)
  //}
  
  //let task = Task {
  //  guard !Task.isCancelled else {
  //    print("Cancelled!")
  //    return
  //  }
  // cooperative cancellation integrates with failable context
  // this will throw and short-circuit the rest of the task
  // if he detects that the current task has been cancelled
  // this can be more ergonomic than checking the boolean isCancelled on Task.
  //  try Task.checkCancellation()
  //  print(Thread.current)
  //}
  
  func doSomething() async throws {
    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
  }
  
  let task = Task {
    let start = Date()
    defer { print("Task finished in", Date().timeIntervalSince(start)) }
    
    // Task.sleep is a throwing function so that it can short-circuit the rest of the work when it detects cancellation.
    // this is in stark contrast to how Threads and DispatchQueues work.
    // try await Task.sleep(nanoseconds: NSEC_PER_SEC)
    // try await doSomething() // this works the same as the above.
    
    // now instead of sleeping, let's make a network request that takes long to respond.
    let (data, _) = try await URLSession.shared.data(from: .init(string: "http://ipv4.download.thinkbroadband.com/1MB.zip")!)
    
    print(Thread.current, "network request finished", data.count)
  }
  
  Thread.sleep(forTimeInterval: 0.5)
  
  task.cancel()
}

enum RequestData {
  @TaskLocal static var requestId: UUID!
  @TaskLocal static var startDate: Date!
}

func databaseQuery() async throws {
  let requestId = RequestData.requestId!
  print(requestId, "Making database query")
  try await Task.sleep(nanoseconds: 500_000_000)
  print(requestId, "Finished database query")
}

func networkRequest() async throws {
  let requestId = RequestData.requestId!
  print(requestId, "Making network request")
  try await Task.sleep(nanoseconds: 500_000_000)
  print(requestId, "Finished network request")
}

// now we can improve on how we approach this in the past
// and mark this function as async.
// this move the responsibility of creating an asynchronous and failable context to the caller of the function.
func response(for request: URLRequest) async throws -> HTTPURLResponse {
  let requestId = RequestData.requestId!
  let start = RequestData.startDate!
  
  defer { print(requestId, "Request finished in", Date().timeIntervalSince(start)) }
  
  // even deeper in these async contexts, we still have access to the requestId
  try await databaseQuery()
  try await networkRequest()
//  print(requestId, "Making database query")
//  try await Task.sleep(nanoseconds: 500_000_000)
//  print(requestId, "Finished database query")
//  print(requestId, "Making network request")
//  try await Task.sleep(nanoseconds: 500_000_000)
//  print(requestId, "Finished network request")
  
  // TODO: do some work to actually generate a response
  return .init()
}

RequestData.$requestId.withValue(UUID()) {
  RequestData.$startDate.withValue(Date()) {
    Task {
      _ = try await response(for: .init(url: .init(string: "https://www.pointfree.co")!))
    }
  }
}

// this namespacing can also be used to house other Task locals we might want to use throughout the application.
// Alternatively you could also define a single struct to hold all of these values and then have a single @TaskLocal.
//enum MyLocals {
  // we're using implicitly uwrapped optional here so that it louds a failure whenever you access an uninitialized task local.
//  @TaskLocal static var id: Int!
  
  // Other Task locals
  // @TaskLocal var api: APIClient
  // @TaskLocal var database: DatabaseClient
  // @TaskLocal var stripe: StripeClient
//}

//func doSomething() async {
//  print("doSomething:", MyLocals.id!)
//}

// print("before:", MyLocals.id) // this prints nil if not initialized
// to initialize it we use a method on the property wrapper:
//MyLocals.$id.withValue(42) {
//  print("withValue:", MyLocals.id!) // 42
  
  // how to retain the local much longer
//  Task {
    // print("Task:", MyLocals.id!) // prints 42 even though the Task's closure has escaped from the operation closure we're using in withValue: it executed after the local went nil.
//  }
  
//  Task {
//    MyLocals.$id.withValue(1729) {
      // spin off another Task that inherits those locals
//      Task {
//        try await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
//        print("Task 2:", MyLocals.id!)
//      }
//    }
    
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    Task {
      // this still prints 42. this is because the moment we create a task,
      // it captures all the Task's local
//      print("Task:", MyLocals.id!) // still printed 42
//      await doSomething()
//    }
//  }
//}
// print("after:", MyLocals.id) // nil

Thread.sleep(forTimeInterval: 5)
