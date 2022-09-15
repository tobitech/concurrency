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

func taskStorageAndCooperation() {
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
    
    // assuming we want to track analytics data with a fire and forget operation.
    // this also have access to the requestId.
    Task {
      print(RequestData.requestId!, "Track analytics")
    }
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
  
  //RequestData.$requestId.withValue(UUID()) {
  //  RequestData.$startDate.withValue(Date()) {
  //    Task {
  //      _ = try await response(for: .init(url: .init(string: "https://www.pointfree.co")!))
  //    }
  //  }
  //}
  
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
  
  //for _ in 0..<workcount {
  //  Thread.detachNewThread {
  //    while true { } // simulate something intense
  //  }
  //}
  
  // without all the thread contention above, it takes about 0.089sec to run.
  // this shows how in Threads two many threads are created that contends with this one for resources.
  // all these thread contention can hurt the performance of other threads that need to do their job
  //Thread.detachNewThread {
  //  print("Starting prime thread") // takes a long time to get the prime
  //  nthPrime(50_000)
  //}
  
  //for n in 0..<workcount {
  //  Task {
  // all the concurrent cooperative thread are just blocked in this while loop.
  // this looks like a step back for wanting to write code that executes simultaneously.
  // to solve this we should use non-blocking APIs for asynchronous work
  // while true { } // simulate something intense
  
  // non-blocking asynchronous work done by URLSession.
  // assuming we want to load 1,000 1MB files.
  // running this: notice that our nthPrime Task immediately returns a response.
  //    let (data, _) = try await URLSession.shared.data(from: .init(string: "https://ipv4.download.thinkbroadband.com/1MB.zip")!)
  //    print(n, Thread.current)
  //  }
  //}
  
  // if we can't use Task.sleep or any of those Apple's non-blocking asynchronous APIs,
  // we can use `yield` to give up some resources so that other Tasks can use.
  for _ in 0..<workcount {
    Task {
      // simulate something intense
      // with yield the nthPrime task runs immediately
      while true {
        await Task.yield() // we're creating a suspension point so that other tasks will get a turn on this thread.
        // at at some later time, when the runtime has felt it has giving enough time to other tasks it will resume us.
        // this is an important tool for cooperation.
      }
    }
  }
  
  Task {
    print("Starting prime thread") // seems this task isn't even getting a chance to start.
    nthPrime(50_000)
  }
}

class Counter {
  let lock = NSLock()
  var count: Int = 0
  func increment() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.count += 1
  }
}

let counter = Counter()

//for _ in 0..<workcount {
//  Task {
//    counter.increment()
//  }
//}
//
//Thread.sleep(forTimeInterval: 2)
//print("counter.count", counter.count)

// Swift prohibits capturing mutable variables inside asynchronous contexts
//func doSomething() {
//  var count = 0
//  Task {
//    // 🛑 Reference to captured var 'count' in concurrently-executing code
//    print(count)
//  }
//}

// Some questions on why the prohibition is a good thing.
// Q1: If you capture an outside variable in the Task, should mutable on the outside be visible on the inside?
// What if after the Task, we change the value of the count
// and then in the Task we slept for a second, what should count be in the Task?
// should it be 0? or 1?
//func doSomething() {
//  var count = 0
//  Task {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    print(count) // 0? 1? // 🛑
//  }
//  count = 1
//}

// Q2: What if we could mutate the count inside of the Task and then we slept the Thread for a second before print the count.
// What should the count be, 0? or 1?
//func doSomething() {
//  var count = 0
//  Task {
//    count = 1 // 🛑
//  }
//  Thread.sleep(forTimeInterval: 1)
//  print(count) // 0? 1?
//}

// Both of these questions are confusing, since they do not read linearly from top to bottom. If we allow mutable captures we open ourselves up to race conditions.
// Mutable captures like these are allowed in merely escaping closures, meaning it's possible to introduce a race condition without the compiler saying a peep.
// This shows how tricky multithreading programming can be. we have a code that appears to work but then it can do something unexpected.
// So outlawing mutable captures in concurrent contexts make it so that we don't even have to answer these questions.
//func doSomething() {
//  var count = 0
//
//  for _ in 0..<workcount {
//    // `detachNewThread` takes an escaping closure.
//    Thread.detachNewThread {
//      // we're allowing each thread to try and increment the count.
//      count += 1 // No compiler warning
//    }
//  }
//
//  Thread.sleep(forTimeInterval: 1)
//  print(count) // 999 it's even closer because it's a local variable rather than when we tried to access the count inside a Counter class.
//}

// Although mutable captures are not allowed, immutable captures are just fine
//func doSomething() {
//  let count = 0 // was previously declared with var
//  Task {
    // no risk of race conditions in this code cause Swift knows it's immutable
//    print(count) // No compiler error, because we declared variable with let
//  }
  
//  Thread.sleep(forTimeInterval: 1)
//  print(count)
//}

// Even if count is a mutable `var`, if we explicity capture the count when we spin up the Task
//func doSomething() {
//  var count = 0 // was previously declared with var
//  Task { [count] in
//    // this captured count is untethered to the variable outside.
//    print(count) // No compiler error, because we are only grabbing an immutable copy of the variable at the moment of creating the Task.
//  }
//
//  Thread.sleep(forTimeInterval: 1)
//  print(count)
//}

// There are more ways the compiler can help us find these kinds of race conditions.
// Currently these tools are gated behind a Swift flag (as of this tutorial 15/09/2022).
// We can hop into those diagnostics in our package, by adding a flag to our swiftsetting that enables the concurrency warning.
// Now we should get a warning even on the previous approach.
// This warning will be an error in the future.
//func doSomething() {
//  for _ in 0..<workcount {
//    Task {
//      counter.increment() // ⚠️ Capture of ‘counter’ with non-sendable type ‘Counter’ in a @Sendable closure
//    }
//  }
//
//  Thread.sleep(forTimeInterval: 2)
//  print("counter.count", counter.count)
//
//  var count = 0
//  Task { [count] in
//    print(count)
//  }
//}

// doSomething()

// As we're seen before a class holding a piece of mutable state is not typically safe to pass through multiple closures running concurrently, you have to put in a little extra work to make it safe by using a lock internally.
// On the other hand, some types are safe to pass between concurrent boundaries
// These compiles without error because the `Int` type conforms to the Sendable protocol.
// In face majority of the types in the standard library conform to Sendable simply because they're just value types. i.e. booleans, strings, arrays of Sendables, dictionaries of Sendables etc.
//  var count = 0
//  Task { [count] in
//    print(count)
//  }

//  let count = 0
//  Task {
//    print(count)
//  }

// Any value type whose fields are Sendable also can be passed across concurrent boundaries.
//func doSomething() {
  
  // even though we didn't explicitly mark the `User` type as being Sendable
  // compiler magic automatically applies the conformance for us.
  // we can also do it explitictly if we want, but it isn't necessary
//  struct User { // : Sendable {
//    var id: Int
//    var name: String
//  }
//  let user = User(id: 42, name: "Blob")
//  Task {
//    print(user) // No compiler warning
//  }
//}

// So we can largely stay in the sendable world as long as we are creating simple value types that are composed of other sendable value types.
// But, as our data types grow more complex we may accidentally fall out of the purview of automatic sendable conformance. For example, suppose we did something seemingly innocuous like adding an attributed string to our model for the bio of the user:
func doSomething() {
  
  // AttributedString is not Sendable yet (as at this date 15/09/2022)
  struct User: Sendable {
    var id: Int
    var name: String
    // we get localised warning when we explicitly conform User to Sendable.
    // var bio: AttributedString // ⚠️ Stored property 'bio' of 'Sendable'-conforming struct 'User' has non-sendable type 'AttributedString'
  }
  // let user = User(id: 42, name: "Blob", bio: "")
  let user = User(id: 42, name: "Blob")
  Task {
    // the warning shows because we can no longer prove to the compiler that it's safe to send `User` across concurrent boundaries.
    print(user) // ⚠️ Capture of ‘user’ with non-sendable type ‘User’ in a @Sendable closure
  }
}

// Reference types can also be made Sendable.

Thread.sleep(forTimeInterval: 5)
