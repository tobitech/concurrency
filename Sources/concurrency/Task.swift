// ⚠️ Add '@preconcurrency' to suppress 'Sendable'-related warnings from module 'Foundation'
@preconcurrency import Foundation

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

//class Counter {
//  let lock = NSLock()
//  var count: Int = 0
//  func increment() {
//    self.lock.lock()
//    defer { self.lock.unlock() }
//    self.count += 1
//  }
//}

// let counter = Counter()

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
//func doSomething() {
//
//  // AttributedString is not Sendable yet (as at this date 15/09/2022)
//  struct User: Sendable {
//    var id: Int
//    var name: String
//    // we get localised warning when we explicitly conform User to Sendable.
//    // var bio: AttributedString // ⚠️ Stored property 'bio' of 'Sendable'-conforming struct 'User' has non-sendable type 'AttributedString'
//  }
//  // let user = User(id: 42, name: "Blob", bio: "")
//  let user = User(id: 42, name: "Blob")
//  Task {
//    // the warning shows because we can no longer prove to the compiler that it's safe to send `User` across concurrent boundaries.
//    print(user) // ⚠️ Capture of ‘user’ with non-sendable type ‘User’ in a @Sendable closure
//  }
//}

// Reference types can also be made Sendable.
// We get some warnings when we conform a class to Sendable.
// It seems reference types cannot automatically conform even if they hold on two simple value type fields.
// We have to mark it as final, because another subclass of the class can introduce some non-sendable things, such as introducing mutable state. That removes the first warning.
// Change `var` to let to address the second warning.
// Now we get rid of all the warnings. Although we now have limited capabilities since the class can no longer change its internal states at all which makes it behave similar to the struct version we had, but that's the cost of doing business with multithreaded code
// func doSomething() {
// class User: Sendable { // ⚠️ Non-final class 'User' cannot conform to 'Sendable'; use '@unchecked Sendable'
// final class User: Sendable {
// var id: Int // ⚠️ Stored property 'id' of 'Sendable'-conforming class 'User' is mutable
// var name: String // ⚠️ Stored property 'id' of 'Sendable'-conforming class 'User' is mutable
//    let id: Int
//    let name: String
//
//    init(id: Int, name: String) {
//      self.id = id
//      self.name = name
//    }
//  }
//  let user = User(id: 42, name: "Blob")
//  Task {
//    print(user)
//  }
//}

// The Swift compiler doesn't know we've added some work to make it safe to work with in asychronous contexts.
// that's why when we mark this as Sendable, we still get those warnings.
// ⚠️ Non-final class 'Counter' cannot conform to 'Sendable'; use '@unchecked Sendable'
// ⚠️ Stored property 'lock' of 'Sendable'-conforming class 'Counter' has non-sendable type 'NSLock'
// ⚠️ Stored property 'count' of 'Sendable'-conforming class 'Counter' is mutable
// We can't make NSLock Sendable, and we don't want to make count field let.
// But since we're sure we've done some work to make it safe we can use @unchecked Sendable to get rid of the warning.
// So we should know that anytime we use @unchecked Sendable, we are operating totally outside of the pureview of the compiler.
// It's actually possible that in the future we introduce changes to state that makes it no longer safe to pass across concurrent boundaries and swift will not be able to detect that.
// Swift gives us some tools to deal with this situation, we will look at that later.
//class Counter: Sendable {
//class Counter: @unchecked Sendable {
//  let lock = NSLock()
//  var count: Int = 0
//  func increment() {
//    self.lock.lock()
//    defer { self.lock.unlock() }
//    self.count += 1
//  }
//}

// Let's explore @Sendable attribute to closures.
//class Counter {
//  let lock = NSLock()
//  var count: Int = 0
//  func increment() {
//    self.lock.lock()
//    defer { self.lock.unlock() }
//    self.count += 1
//  }
//}
//
//func doSomething() {
//  let counter = Counter()
//
//  Task {
//    counter.increment() // ⚠️ Capture of 'counter' with non-sendable type 'Counter' in a `@Sendable` closure
//  }
//}

// Refresher on @escaping
// It restricts how you're allowed to use a closure that is passed to a function

// consider a normal function that takes a closure.
//func perform(work: () -> Void) {
//  print("begin")
//  // we can invoke the closure within the lifetime of `perform`
//  work()
//  // we can even invoke it a bunch of times
//  work()
//  // we can also sprinkle little bit of work in between invoking it
//  print("middle")
//  work()
//  print("middle")
//  work()
//  print("end")
//}

// Now assuming you want to do some more interesting things you will most likely butt heads with the compiler.
// something like making a network request then calling the closure afterwards.
// if we do that, we get a compiler error that our closure `work()` is not marked as escaping but we are using it in an escaping context.
// swift is complaining because we can only execure work after the long work has ended
// without distinction between escaping and non-escaping closures, we can write a lot of seemingly reasonable code that will be capable of doing some unreasonable things
// func perform(work: () -> Void) {
// print("begin")
// this isn't allowed
//  URLSession.shared.dataTask(with: .init(string: "http://ipv4.download.thinkbroadband.com/1MB.zip")!) { _, _, _ in // 🛑 Escaping closure captures non-escaping parameter 'work'
//    work()
//  }

// this is not allowed as well
// 🛑 Escaping closure captures non-escaping parameter 'work'
//  DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//    work()
//  }
// print("end")
//}

// It prints accordingly
//perform {
//  print("Hello")
//}

//func incrementAfterOneSecond(value: inout Int) {
//  // 🛑 Escaping closure captures 'inout' parameter 'value'
//  DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//    value += 1
//  }
//}

// if the above were to be valid (without compiler error)
// do we expect count to be 0? or 1?
//var count = 0
//incrementAfterOneSecond(value: &count)
//assert(count == 0) // we expect it to be 0 here since increment doesn't happen until after 1 sec
//Thread.sleep(forTimeInterval: 1) // so let's sleep for 1sec and see what count is
// what do we expect count to be. if we get 1 that will be weird because there was no mutable between the first assertion after the time we slept for.
// it will make value types seem as though they're reference types.
// this kind of scenario is exactly what value types were created for to avoid.
// so the Swift compiler is preventing us from writing code that does not make sense, it is just not valid to pass a mutable value type (inout data) that can cross an escaping boundary.
// only non-inout values are allowed to cross escaping boundaries.
// so if we really wanted to implement the increment function, we will use a reference type rather than a value type.
// assert(count == 1)

// Notice we didn't get the error we got when we used `inout`
//func incrementAfterOneSecond(counter: Counter) {
//  DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//    counter.increment()
//  }
//}

//var counter = Counter()
//incrementAfterOneSecond(counter: counter) // ⚠️ Reference to var 'counter' is not concurrency-safe because it involves shared mutable state
//assert(counter.count == 0) // ⚠️ Reference to var 'counter' is not concurrency-safe because it involves shared mutable state
//Thread.sleep(forTimeInterval: 1)
//assert(counter.count == 1) // ⚠️ Reference to var 'counter' is not concurrency-safe because it involves shared mutable state

// Now when we use escaping, the error goes away.
// By using @escaping here we're restricting what kind of closure we're allowed to be passed to perform(:) since it's going to be used asynchronously.
//func perform(work: @escaping () -> Void) {
//  print("begin")
// this isn't allowed
//  URLSession.shared.dataTask(with: .init(string: "http://ipv4.download.thinkbroadband.com/1MB.zip")!) { _, _, _ in // 🛑 Escaping closure captures non-escaping parameter 'work'
//    work()
//  }

// this is not allowed as well
//  DispatchQueue(label: "delay").asyncAfter(deadline: .now() + 1) {
//    work()
//  }
//  print("end")
//}

// It prints after 1sec.
// but the order is somehow weird
// begin
//end
//hello
//perform {
//  print("hello")
//}

// Swift async keyword defines one kind of asynchrony and we're allowed to not use @escaping for that one kind without getting error. (This is counter-intuitive)
// the only difference of this non-escaping one is that we can only call perform when we have an async context available.
//func perform(work: () -> Void) async throws {
//  print("begin")
//  try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//  work() // we're calling this outside of an escaping context
// we could even do other asynchronous work here, like sleeping couple of times
// we get this printed
// begin
// hello
// hello
// hello
// end
//  try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//  work()
//  try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//  work()
// or a network request
//    _ = try await URLSession.shared.dataTask(with: .init(string: "http://ipv4.download.thinkbroadband.com/1MB.zip")!)
//  work()
//  print("end")
//}

// It prints in a much better order
// begin
//hello
//end
//Task {
//  try await perform {
//    print("hello")
//  }
//}

// We could even access an inout value inside the closure
// this seems scary but Swift knows the perform function is asynchronous and it knows that it will complete once all the asynchronous work is done, therefore there is no need for an escaping closure.
//func perform(value: inout Int, work: () -> Void) async throws {
//  print("begin")
//
//  let (data, _) = try await URLSession.shared.data(from: .init(string: "http://ipv4.download.thinkbroadband.com/1MB.zip")!)
//  work()
//  value += data.count
//  print("end")
//}

// It prints in a much better order
// begin
// hello
// end
// count 1048576
//Task {
//  var count = 0
//  try await perform(value: &count) {
//    print("hello")
//  }
//  print(count)
//}

// The @Sendable attribute is very similar, except instead of protecting you from passing unsafe closures to asynchronous contexts it protects you from passing unsafe closures to concurrent contexts.
// So, let’s see what kind of new problems can crop up when dealing with concurrent code, and see what the compiler has to say about it.

// What if we wanted to run each unit of work() concurrently rather than serially, one after the other. using a Task {}
// the moment we do that we get some warnings and some errors.
// 🛑 Escaping closure captures non-escaping parameter 'work'. This is because the closure to initialize a Task {} is escaping and our work isn't.
// so we can mark it as escaping to remove that error.
// ⚠️ Capture of 'work' with non-sendable type '() -> Void' in a `@Sendable` closure. this is because we're using work that is not @Sendable inside a context that is @Sendable.
// remember the init function of Task is like this.
// public init(priority: TaskPriority? = nil, operation: @escaping @Sendable () async throws -> Success)
// in Swift 6 this warning will become an error.

//func perform(work: () -> Void) async throws {
//func perform(work: @escaping () -> Void) async throws {
//  print("begin")
//  Task.init { // 🛑 Escaping closure captures non-escaping parameter 'work'
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work() // ⚠️ Capture of 'work' with non-sendable type '() -> Void' in a `@Sendable` closure
//  }
//
//  Task {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//
//  Task {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//  print("end")
//}
//
//Task {
//  try await perform {
//    print("hello")
//  }
//}

// To see why this warning is a good thing, and why we would even want it to be an error someday in the future, let’s see what kind of seemingly reasonable code we can write that turns out to be completely unreasonable.
// Let's explore some things assuming there are no warnings.
// Remove async throws, since we're not doing any asynchronous work inside but rather doing concurrent work with Tasks.
// func perform(work: @escaping () -> Void) async throws {
//func perform(work: @escaping () -> Void) {
//  Task.init { // 🛑 Escaping closure captures non-escaping parameter 'work'
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work() // ⚠️ Capture of 'work' with non-sendable type '() -> Void' in a `@Sendable` closure
//  }
//
//  Task {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//
//  Task {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//}

// Let's do something here that's still friendly to @escaping but not friendly to @Sendable.
// However this code is not safe at all and will lead to some surprising results if we allow it.
//Task {
//  var count = 0
//  perform {
//    print("hello")
//    count += 1
//  }
//}
// Say we repeat this code a thousand times.
// We got 2972 instead of 3000 because the code has race conditions.
// There's nothing about perform that lets us know that concurrent things are going to be happening on the inside.
// So, without the compiler knowing about code that is safe to run concurrently, it is possible to write seemingly reasonable code that is completely wrong.
//Task {
//  var count = 0
//  for _ in 0..<workcount {
//    perform {
//      count += 1
//    }
//  }
//  try await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
//  print(count) // 2972 - we expected 3000.
//}

// Let's see what happens when we add the @Sendable attribute.
// Now all the warning go away, because we've told the compiler that only Sendable closures are allowed to be passed in, so we're allowed to fire off as many tasks as we want and invoke the work, because work() is safe to do concurrently
// The code below it now throws an error // 🛑 Mutation of captured var 'count' in concurrently-executing code because it's no longer safe to concurrenly capture and mutate a variable.
// Swift now knows enough about the intended use of the closure that it's going to be used in asynchronous and concurrent manner so it can just outlaw certain types of closures from being able to perform.
//func perform(work: @escaping @Sendable () -> Void) {
//  Task.init {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//
//  Task {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//
//  Task {
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//}
//
//Task {
//  var count = 0
//  for _ in 0..<workcount {
//    // we're no longer allowed to capture mutable variables from the outside, even though this was a safe thing to do with escaping closures.
//    // we can now only do concurrent friendly things inside here.
//    perform {
//      // count += 1 // 🛑 Mutation of captured var 'count' in concurrently-executing code
//      print("hello")
//    }
//  }
//  try await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
//  print(count)
//}

// You can also use @Sendable to help make types that hold onto closures conform to the Sendable protocol.
// For example, suppose we were designing a lightweight dependency that abstracts over access to a database.
// If we follow the design we’ve discussed many types on Point-Free we might end up with a struct that has a few endpoints for performing database operations:
//struct User {}

// unfortunately this type is not Sendable and cannot be used across concurrent boundaries.
//struct DatabaseClient {
// Let's try to make it sendable. We get some warnings on the closures inside of it. // ⚠️ Stored property 'fetchUsers' of 'Sendable'-conforming struct 'DatabaseClient' has non-sendable type '() async throws -> [User]' because the compiler doesn't know what type of closures they are - they could be reading and writing mutable variables which is not safe.
// So we can mark them as Sendable to only allow Sendable closures to be passed in.
// and that will restrict the kind of closures that we could use when constructing a database client.
// struct DatabaseClient: Sendable {
//struct DatabaseClient { // we can even get rid of : Sendable conformance on the type and it will be inferred automatically.
// var fetchUsers: () async throws -> [User]
// var createUser: (User) async throws -> Void
//  var fetchUsers: @Sendable () async throws -> [User]
//  var createUser: @Sendable (User) async throws -> Void
//}
//
//extension DatabaseClient {
//  static let live = Self(
//    fetchUsers: { fatalError() },
//    createUser: { _ in fatalError() }
//  )
//}

// let's say the perform function needed the DatabaseClient dependency
// we now get some warnings ⚠️ Capture of 'client' with non-sendable type 'DatabaseClient' in a `@Sendable` closure
//func perform(
//  client: DatabaseClient,
//  work: @escaping @Sendable () -> Void
//) {
//  Task.init {
//    _ = try await client.fetchUsers() // ⚠️ Capture of 'client' with non-sendable type 'DatabaseClient' in a `@Sendable` closure
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//
//  Task {
//    _ = try await client.fetchUsers()
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//
//  Task {
//    _ = try await client.fetchUsers()
//    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//    work()
//  }
//}

//Task {
//  var count = 0
//  for _ in 0..<workcount {
//    perform(client: .live) {
//      print("hello")
//    }
//  }
//  try await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
//  print(count)
//}

// The use of @unchecked Sendable should be a huge red flag because we will be operating outside the pureview of the compiler.
// Sometimes it's necessary to use this attribute like when interfacing with old code but at the end of the day you are just telling the compiler to trust us that everything is kosher
// We will add a decrement() endpoint, and a max field to hold on to the maximum value the counter has ever held.
// We will also make the class unsafe to pass across concurrent boundaries by changing how we lock the increment to only affect the count up, removing the defer.
// // this change is subtle but the compiler can't hold our hands that something bad has happened
// This is why there is an entirely new kind of data type in Swift 5.5 that allows you to protect a piece of mutable state from these kinds of data races. And this data type is deeply ingrained into the language so that the compiler can know when you are using it in a way that could potentially lead to data races.
//class Counter: @unchecked Sendable {
//	let lock = NSLock()
//	var count: Int = 0
//	var maximum = 0
//
//	func increment() {
//		self.lock.lock()
//		// defer { self.lock.unlock() }
//		self.count += 1
//		self.lock.unlock()
//		self.maximum = max(self.count, self.maximum)
//	}
//
//	func decrement() {
//		self.lock.lock()
//		defer { self.lock.unlock() }
//		self.count -= 1
//	}
//}

//func doSomething() {
//	let counter = Counter()
//
//	Task {
//		counter.increment()
//	}
//}

// actor is an entirely new kind of data type in Swift 5.5 that allows you to protect a piece of mutable state from these kinds of data races. And this data type is deeply ingrained into the language so that the compiler can know when you are using it in a way that could potentially lead to data races.
// Structs and enums are Swift’s tools for modeling value types that represent holding multiple data types at once or holding a single choice from multiple data types.
// Reference types represent data that has identity and can be passed around by reference.
// And actors are also reference types, but that further synchronize access to its data and methods.
// so we can implement this actor much like how we first implemented the Counter class.
// This is exactly how we wanted to implement the Counter class but quickly found out that there was the potential for data races when invoking the increment method.
// Notice that we don’t have any locks or dispatch queues, and we don’t need to maintain a private underscored piece of mutable state just so that we can lock access to it in a computed property. We also don’t have to worry about setting the maximum value outside the lock because the entire method is synchronized. Overall this type is much simpler than the class-based counter type.
actor CounterActor {
	var count = 0
	var maximum = 0
	func increment() {
		self.count += 1
		// self.maximum = max(self.count, self.maximum)
		// let's try moving setting maximum to another method.
		// we didn't have to await this. which means working within an actor can be quite simple and ergonomic.
		// it's only when the outside world needs to deal with the actor that we have to worry about working in an asynchronous context.
		self.computeMaximum()
	}
	
	func decrement() {
		self.count -= 1
	}
	
	private func computeMaximum() {
		self.maximum = max(self.count, self.maximum)
	}
}

let counter = CounterActor()

//for _ in 0..<workcount {
//  Thread.detachNewThread {
// this is example of Swift helping us to not do something that can lead to data races.
// we are not allowed to call actor methods from any context because the point of actor is to protect the data it holds.
// you can only invoke the increment() method if you're in an asynchronous context, because we don't want to lock any thread, which can be distrastrous.
// counter.increment() // 🛑 Actor-isolated instance method 'increment()' can not be referenced from a non-isolated context.
//  }
//}

// so instead of detaching a new Thread, we will spin off a Task
// It may seem strange that we have to await invoking the increment method, especially since the method is not even declared as async:
// As far as the actor is concerned the method is perfectly synchronous. It can make any changes it wants to its mutable state without worrying about other threads because actors fully synchronize its data and methods.
// But as far as the outside world is concerned, this method cannot be called synchronously because there may be multiple tasks trying to invoke the increment method at once. The actor needs to do the extra work in order to synchronize access. The way the actor can do this efficiently is by operating in an asynchronous context.
func synchronisation() {
	// for _ in 0..<workcount {
	for _ in 0..<workcount { // we could even run it on larger work count.
		Task {
			// to show that we're not exploding the number of threads
			// print("increment", Thread.current)
			await counter.increment() // should prints 10,000 without the decrement Task below.
		}
		// let's see what happens by running the same amount of work to decrement.
		Task {
			// print("decrement", Thread.current)
			await counter.decrement() // should now prints 0 with the introduction of this.
		}
	}
	
	Thread.sleep(forTimeInterval: 1)
	// even accessing the property outside an asynchronous context is not allowed.
	// This is because it’s possible to try reading the count while another task is in the middle of updating it, which could lead us to getting an out-of-date value.
	// print("counter.count", counter.count) // 🛑 Actor-isolated property ‘count’ can not be referenced from a non-isolated context
	
	Task {
		await print("counter.count", counter.count)
		// does this means we've introduced a race condition in our code and that the actor isn't protecting us?
		// the answer is no, there is no race condition, it's just an example of something that is non-deterministic by it very nature.
		// We have 1,000 increment tasks and 1,000 decrement tasks running concurrently, and the order that they run is not going to be deterministic. Sometimes we may get a long stretch of consecutive increment tasks running, allowing the max to get a little high, and other times it may be more balanced of alternating incrementing and decrementing tasks. There really is no way to know, and that’s why this value can change.
		// This is yet another example of how difficult multithreaded programming can be. Just because we have extremely powerful tools for preventing data races doesn’t mean we have removed the possibilities of non-determinism creeping into our code.
		// If we don’t want that kind of non-determinism then we shouldn’t be performing concurrently.
		// The issue of data races is completely seperate from non-determinism and Swift tools are tuned to address data races not non-determinism.
		await print("counter.maximum", counter.maximum) // we get 8 // then 6
	}
}

// Thread.sleep(forTimeInterval: 5)
