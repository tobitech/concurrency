import Foundation

// As we’ve seen before, it’s possible for tasks to be resumed after a suspension point on pretty much any thread. It doesn’t have to necessarily be the one you were on before the suspension point.
// Usually when working with tasks, you shouldn’t even need to think about what thread you’re working on, but what do we do for those times that we really do need to execute on a particular thread, like the main thread?

// Let's suppose we have a SwiftUI view model that has an endpoint that is asynchronous
// class ViewModel: ObservableObject {
// to make this Sendable we would have to make all the properties immutable, which is not what we want to do.
// final class ViewModel: ObservableObject, Sendable {
	// @Published var count = 0 // ⚠️ Stored property '_count' of 'Sendable'-conforming class 'ViewModel' is mutable
	
	// sadly, this code compiles with no warning even though it's very wrong, because SwiftUI doesn't allow you to mutate @Published properties on non main threads.
	// to do this let's print warning if we're not on the main thread.
	// func perform() async throws {
		// try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//		if !Thread.current.isMainThread {
//			print("🟣 Mutating @Published property on a non-main thread.")
//		}
//		self.count = .random(in: 1...1_000)
		
		// let's reach out to some old tools to solve this.
		// we now know this is executing on the main thread. however we're getting a compiler warning.
		// thats because the view model is not a Sendable type and it's not easy to make it a Sendable type.
		// Another problem is that this DQ.main.async closure apart from not having all the nicities of Swift, it would not inherit the current Task locals
//		DispatchQueue.main.async {
//			if !Thread.current.isMainThread {
//				print("🟣 Mutating @Published property on a non-main thread.")
//			}
//			self.count = .random(in: 1...1_000) // ⚠️ Capture of 'self' with non-sendable type 'ViewModel' in a `@Sendable` closure
//		}
//		MyLocals.$id.withValue(42) {
//			defer { print("withValue scope ended")}
//			DispatchQueue.main.async {
//				if !Thread.current.isMainThread {
//					print("🟣 Mutating @Published property on a non-main thread.")
//				}
				// self.count = .random(in: 1...1_000) // ⚠️ Capture of 'self' with non-sendable type 'ViewModel' in a `@Sendable` closure
				
				// This crashes because this is an escaping closure, the local is only available during the life time of the withValue closure but because DQ.main.async is escaping it's running later, even after the life time of the withValue closure.
				// print("On the main thread")
				// output
//				withValue scope ended
//				On the main thread
				
			// self.count = MyLocals.id // ⛔️ Thread 1: Swift runtime failure: Unexpectedly found nil while implicitly unwrapping an Optional value
				
//			}
//		}
//	}
//}

// All of this is reason enough for us to look for another way of forcing work to be done on the main thread. Just as threads have the concept of a “main thread”, and dispatch queues have the concept of a “main queue”, actors have the concept of a “main actor” and it’s an actor type in the standard library literally called MainActor:
// The main actor type comes with a special endpoint for running a synchronous closure on the main thread:
//class ViewModel: ObservableObject {
//	@Published var count = 0
//
//	func perform() async throws {
//		try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//		await MyLocals.$id.withValue(42) {
//			defer { print("withValue scope ended")}
			// Even with all these, we still have a warning
			// While it is true that MainActor.run is the best way to synchronously run code on the main thread, it still is not appropriate to pass non-sendable data across this boundary.
			// Even though the closure passed to run will be executed serialised, we don't know if there is another thread somewhere that want to access this property and so we can't gaurantee it is isolated from other concurrent code.
			// If you invoked MainActor.run multiple times you have a chance for a race condition:
			// await MainActor.run { // 🛑 'async' call in a function that does not support concurrency
				// self.count = .random(in: 1...1_000) // ⚠️ Capture of 'self' with non-sendable type 'ViewModel' in a `@Sendable` closure
			// }
//			DispatchQueue.main.async {
//				if !Thread.current.isMainThread {
//					print("🟣 Mutating @Published property on a non-main thread.")
//				}
//				self.count = MyLocals.id
//			}
//		}
//	}
//}


// There is another way to use MainActor that mitigates all these issues, you can actually use it as an attribute to decorate an entire function or method and then every single line in that scope will be executed on the main actor and hence the main thread.
// Now it’s important to note that just because the perform() function is marked as @MainActor it doesn’t mean everything is performed on the main thread.
// Any suspension points are still allowed to be executed by other actors, and hence other threads. We can perform completely asynchronous and concurrent work in this function even though the whole thing is marked as @MainActor.
//class ViewModel: ObservableObject {
//	@Published var count = 0
//
//	@MainActor
//	func perform() async throws { // async means we can still perform asynchronous work in here even though it's marked as @MainActor.
		
		// however if we stil perform intense CPU work on the main thread, it will still block it up like computing nth prime for large number.
		// this is literally done on the main thread, there is no suspension point here.
		// nthPrime(2_000_000)
		
		// here is an example of a suspension point despite being inside a function marked with @MainActor,
		// this Task.sleep did not block the MainActor, it still freed up the main thread so that other Tasks could use it
//		try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//		MyLocals.$id.withValue(42) {
//			defer { print("withValue scope ended")}
//			if !Thread.isMainThread {
//				print("🟣 Mutating @Published property on a non-main thread.")
//			}
//			self.count = MyLocals.id
			// print(self.count)
			// Ouput
			// 42
			// withValue scope ended
//		}
//	}
//}


// We can also mark the entire class as being MainActor.
// This implicitly marks all initializers, methods and computed properties as @MainActor.
// It even further makes the class Sendable.
// However, by declaring it as @MainActor we know that all interactions with it will be serialized to the main thread, and that makes it safe to use across concurrent boundaries.

// @MainActor
// class ViewModel: ObservableObject {
//class ViewModel: ObservableObject { // }, Sendable {
//	@Published var count = 0
//
//	func perform() async throws {
		
		// this compiles with no warnings
		// without the @MainActor, we get a warning ⚠️ Capture of 'self' with non-sendable type 'ViewModel' in a `@Sendable` closure
		// Task {
			// self.count += 1
			// print(Thread.current) // <_NSMainThread: 0x10110aac0>{number = 1, name = main}
		// }
		
		// If we detach we get a non main thread.
		// This also applies to other concurrent operations that don't inherit the current actor context i.e.g async let,
		// if we use those in here, we will see that they execute on non-main threads
//		Task.detached {
//			print(Thread.current) // <NSThread: 0x101429f40>{number = 2, name = (null)}
//		}
		
//		try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//		MyLocals.$id.withValue(42) {
//			defer { print("withValue scope ended")}
//			if !Thread.isMainThread {
//				print("🟣 Mutating @Published property on a non-main thread.")
//			}
//			self.count = MyLocals.id
//			print(self.count)
//		}
//	}
//}

// It turns out you can go really, really far without ever thinking about threads. In fact, you can do pretty much everything we’ve discussed on just a single thread.
// To explore this, let’s fire up a bunch of concurrent work, and force it all to run on the main thread. We’ll start up a group with one task that prints every quarter second:

@MainActor
class ViewModel: ObservableObject {
	@Published var count = 0

	func perform() async throws {
		await withThrowingTaskGroup(of: Void.self, body: { group in
			group.addTask { @MainActor in
				while true {
					try await Task.sleep(nanoseconds: NSEC_PER_SEC / 4)
					print(Thread.current, "Timer ticked")
				}
			}
			// The Problem while it took a while before we started seeing anything printed is because we put an intense CPU computation on the main actor, so it completely block every other tasks : i.e. the timer tick and file downloads
			// and as soon it it finished every other task was freed
			group.addTask { @MainActor in
				// nthPrime(2_000_000) // this blocks the main thread
				// this is nthPrime version that yields letting other tasks start immediately.
				await asyncNthPrime(2_000_000)
			}
			for n in 1..<workcount {
				// force all of these to execute on the MainActor
				group.addTask { @MainActor in
					_ = try await URLSession.shared.data(from: .init(string: "http://ipv4.download.thinkbroadband.com/1MB.zip")!)
					print(Thread.current, "Download finished", n)
				}
			}
		})
	}
}


@main
struct Main {
	// having this means we're working in structured programming since we have an async context in main function.
	static func main() async throws {
		let viewModel = ViewModel()
		try await viewModel.perform()
		try await Task.sleep(nanoseconds: NSEC_PER_SEC)
	}
}

// Thread.sleep(forTimeInterval: 2)



//@main
//struct Main {
//	static func main() async throws {
//		try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//		print("done!")
//	}
//}

// The cool thing about immediately having an asynchronous context available, and that context defining the lifetime of the executable, is that we no longer need to add sleeps to the main thread so that work can be performed. That was hacky and imprecise.
// If you find yourself creating a new task it is worth thinking about other ways you could have an asynchronous context provided to you from a parent scope.


// @preconcurrency import Foundation

// Let's suppose for a moment that Swift doesn't have for-loops but that it has a `jump` statement.
// We could replicate what for-loops give us by using jump statements.
// suppose we wanted to write a loop that printed all the even numbers between 0 and 100
//func unstructuredProgramming() {
	//var x = 0
	//outer: var y = 0
	// this is how to label a statement, this one labelled as top.
	//top: if x.isMultiple(of: 2) {
	//	print(x)
	//}
	//inner: if x.isMultiple(of: 2) && y.isMultiple(of: 2) {
	//	print(x, y)
	//}
	//y += 1
	//if y <= 100 {
	//	continue inner
	//}
	//x += 1
	//if x <= 100 {
	// do a jump statement to go back to the isMultiple(:) line.
	//	continue outer
	//}
	
	// compared with for-loop
//	for x in 0...100 {
//		for y in 0...100 {
//			if x.isMultiple(of: 2) && y.isMultiple(of: 2) {
//				print(x, y)
//			}
//		}
//	}
//}

// And although Swift does not offer jump statements, at least not in the completely unfettered way that unstructured programming languages do,
// it does still have some tools that leave the world of fully structured programming.
// We’ve already even seen a few of these tools.
// example:
//print("Before")
//Thread.detachNewThread {
	// This creats an execution flow that is untethered from the execution flow that started it.
//	print(Thread.current)
//}
//print("After")

// The current thread prints after the "After" output.
// This clearly means that the code doesn't read from top to bottom
//Before
//After
//<NSThread: 0x1011059b0>{number = 2, name = (null)}

// This lack of top-to-bottom execution means that the tools we know and love from Swift are going to be subtly broken. For example, if we add a defer statement before spinning up the thread, then of course the defer is not going to execute when the thread finishes:
//func thread() {
//	defer { print("Finished") }
//	print("Before")
//	Thread.detachNewThread {
//
//		print(Thread.current)
//	}
//	print("After")
//}
//
//thread()

//Before
//After
//Finished
//<NSThread: 0x100707950>{number = 2, name = (null)}

// The same goes for lock.
// it is not guaranteed that we will be locked inside the thread’s execution:
//func thread() {
//	let lock = NSLock()
//	lock.lock()
//	defer { print("Finished") }
//	print("Before")
//	Thread.detachNewThread {
//
//		print(Thread.current)
//	}
//	print("After")
//	lock.unlock()
//}

// thread()



// Let's re-explore the theoretical server function we played with in the past.
// Ignore the warning, they should go away in the next version of Swift they would have been audited for Sendability.
// This one below:
// ⚠️ Type 'UUID' does not conform to the 'Sendable' protocol
// Because the types `UUID` and `Date` haven't been audited for Sendability in our own Swift's version we can add a `@preconcurrency import to Foundation to suppress all those Sendable warnings.
//enum RequestData {
//	@TaskLocal static var requestId: UUID! // ⚠️ Type 'UUID' does not conform to the 'Sendable' protocol
//	@TaskLocal static var startDate: Date! // ⚠️ Type 'UUID' does not conform to the 'Sendable' protocol
//}

//func databaseQuery() async throws {
//	let requestId = RequestData.requestId!
//	print(requestId, "Making database query")
//	try await Task.sleep(nanoseconds: 500_000_000)
//	print(requestId, "Finished database query")
//}
//
//func networkRequest() async throws {
//	let requestId = RequestData.requestId!
//	print(requestId, "Making network request")
//	try await Task.sleep(nanoseconds: 500_000_000)
//	print(requestId, "Finished network request")
//}

//func response(_ request: URLRequest) async throws -> HTTPURLResponse {
//	// TODO: do the work to turn request into a response
//
//	let requestId = RequestData.requestId!
//	let start = RequestData.startDate!
//
//	defer { print(requestId, "Request finished in", Date().timeIntervalSince(start)) }
//
//	Task {
//		print(RequestData.requestId!, "Track analytics")
//	}
//
//	try await databaseQuery()
//	try await networkRequest()
//
//	// TODO: return real response
//	return .init()
//}

//RequestData.$requestId.withValue(UUID()) {
//	RequestData.$startDate.withValue(Date()) {
//		Task {
//			_ = try await response(.init(url: .init(string: "https://www.pointfree.co")!))
//		}
//	}
//}

// The request takes about 1 whole second. That's because each of the work items database and network take 0.5sec and they ran sequentially.
//5810FDA9-2292-47FF-9761-82E5850FB8DE Making database query
//5810FDA9-2292-47FF-9761-82E5850FB8DE Track analytics
//5810FDA9-2292-47FF-9761-82E5850FB8DE Finished database query
//5810FDA9-2292-47FF-9761-82E5850FB8DE Making network request
//5810FDA9-2292-47FF-9761-82E5850FB8DE Finished network request
//5810FDA9-2292-47FF-9761-82E5850FB8DE Request finished in 1.0899999141693115

// Because these async works are fully independent of each other, we have a potential for speeding up the response code by making them run each in parallel.
// Let's first do this with the tools we know about:
// If we enclose each work in a Task {}, that will be untethered from the scope from which it was started. that will allow us run both of them in parallel.
// But by doing that, we've also lost some of the structured aspect of the code.
// The task initializer is non-blocking, and so execution flow breezes right past while simultaneously the two new tasks get their own execution flow.
// This code no longer reads linearly from top-to bottom.
// Escaping closures allow you to spin off a new execution flow that is independent of the one you are currently working on.
// So, this behavior isn’t surprising, but on the other hand it would be really nice to be able to stay in the structured programming world even when needing to perform two tasks in parallel.
//func response(_ request: URLRequest) async throws -> HTTPURLResponse {
//	// TODO: do the work to turn request into a response
//
//	let requestId = RequestData.requestId!
//	let start = RequestData.startDate!
//
//	defer { print(requestId, "Request finished in", Date().timeIntervalSince(start)) }
//
//	Task {
//		print(RequestData.requestId!, "Track analytics")
//	}
//
//	Task {
//		try await databaseQuery()
//	}
//	Task {
//		try await networkRequest()
//	}
//
//	// TODO: return real response
//	return .init()
//}

// Request finished in no time. 0.004
// This is only happening because the timing is no longer taking into account how long the database and network requests take to execute.
//6141E303-BA65-44FB-9F09-7EAD0FAC2D02 Making database query
//6141E303-BA65-44FB-9F09-7EAD0FAC2D02 Track analytics
//6141E303-BA65-44FB-9F09-7EAD0FAC2D02 Making network request
//6141E303-BA65-44FB-9F09-7EAD0FAC2D02 Request finished in 0.004441976547241211
//6141E303-BA65-44FB-9F09-7EAD0FAC2D02 Finished database query
//6141E303-BA65-44FB-9F09-7EAD0FAC2D02 Finished network request


// Luckily there’s a tool that helps us bridge back to the structured programming world.
// The Task type comes with a property to access the value returned by the task, which of course must be done by awaiting:
//func response(_ request: URLRequest) async throws -> HTTPURLResponse {
//
//	let requestId = RequestData.requestId!
//	let start = RequestData.startDate!
//
//	defer { print(requestId, "Request finished in", Date().timeIntervalSince(start)) }
//
//	Task {
//		print(RequestData.requestId!, "Track analytics")
//	}
	
	// We can hold on to the task
//	let databaseTask = Task {
//		try await databaseQuery()
//	}
//
//	let networkTask = Task {
//		try await networkRequest()
//	}
	
	// try awaiting the return value.
	// this looks sequential, but by the time the value of databaseTask is ready, the networkTask would also have been running in parallel.
//	try await databaseTask.value
//	try await networkTask.value
//
//	return .init()
//}

// Now we see the response code runs faster and waited for the dependent tasks.
// 0.55
// So, it’s pretty cool that even though we had to escape the structured programming world, there are tools to bring us back.
//6F29D7D4-2889-4711-A62B-9E0273790C5D Making network request
//6F29D7D4-2889-4711-A62B-9E0273790C5D Track analytics
//6F29D7D4-2889-4711-A62B-9E0273790C5D Making database query
//6F29D7D4-2889-4711-A62B-9E0273790C5D Finished database query
//6F29D7D4-2889-4711-A62B-9E0273790C5D Finished network request
//6F29D7D4-2889-4711-A62B-9E0273790C5D Request finished in 0.558945894241333

// It turns out that not only does creating new tasks exit the structured programming world, but it also stops participating in cooperative cancellation.
// For example, suppose we cancel the response task 0.1 seconds after we start it:
//

//RequestData.$requestId.withValue(UUID()) {
//	RequestData.$startDate.withValue(Date()) {
//		let task = Task {
//			_ = try await response(.init(url: .init(string: "https://www.pointfree.co")!))
//		}
//		Thread.sleep(forTimeInterval: 0.1)
		// we will hope that this will cancel the database and network request and short-circuit all later work so that it can return quickly
		// but that's not the case.
//		task.cancel()
//	}
//}

// Notice that cancellation doesn't do anything here.
// it still spent the entire duration executing both of those requests.
//45400FBE-D00D-4F4D-AB60-AAEB2D5C4587 Track analytics
//45400FBE-D00D-4F4D-AB60-AAEB2D5C4587 Making network request
//45400FBE-D00D-4F4D-AB60-AAEB2D5C4587 Making database query
//45400FBE-D00D-4F4D-AB60-AAEB2D5C4587 Finished network request
//45400FBE-D00D-4F4D-AB60-AAEB2D5C4587 Finished database query
//45400FBE-D00D-4F4D-AB60-AAEB2D5C4587 Request finished in 0.5544470548629761

// And even if we had a deferred print to see if they are cancelled to the database and network request works
//func databaseQuery() async throws {
//	let requestId = RequestData.requestId!
//	defer { print(requestId, "databaseQuery", "isCancelled", Task.isCancelled) }
//	print(requestId, "Making database query")
//	try await Task.sleep(nanoseconds: 500_000_000)
//	print(requestId, "Finished database query")
//}
//
//func networkRequest() async throws {
//	let requestId = RequestData.requestId!
//	defer { print(requestId, "networkRequest", "isCancelled", Task.isCancelled) }
//	print(requestId, "Making network request")
//	try await Task.sleep(nanoseconds: 500_000_000)
//	print(requestId, "Finished network request")
//}

// We see that isCancelled is false for both operations.
// This seems to run contrary to some of the things we explored in previous episodes. Previously we saw that cancelling the parent task trickled down to the child units of work.
// However, back then we were doing a simple await on the function call, and now we are spinning up new tasks.
//5537830C-6BBF-4884-97DE-E760BDFA7C13 Track analytics
//5537830C-6BBF-4884-97DE-E760BDFA7C13 Making database query
//5537830C-6BBF-4884-97DE-E760BDFA7C13 Making network request
//5537830C-6BBF-4884-97DE-E760BDFA7C13 Finished database query
//5537830C-6BBF-4884-97DE-E760BDFA7C13 databaseQuery isCancelled false
//5537830C-6BBF-4884-97DE-E760BDFA7C13 Finished network request
//5537830C-6BBF-4884-97DE-E760BDFA7C13 networkRequest isCancelled false
//5537830C-6BBF-4884-97DE-E760BDFA7C13 Request finished in 0.5182040929794312

// It's still possible to recover the cancellation behaviour by using another tool called `withTaskCancellationHandler`.
//func response(_ request: URLRequest) async throws -> HTTPURLResponse {
//
//	let requestId = RequestData.requestId!
//	let start = RequestData.startDate!
//
//	defer { print(requestId, "Request finished in", Date().timeIntervalSince(start)) }
//
//	Task {
//		print(RequestData.requestId!, "Track analytics")
//	}
	
	// We can hold on to the task
//	let databaseTask = Task {
//		try await databaseQuery()
//	}
//
//	let networkTask = Task {
//		try await networkRequest()
//	}
	
	// It allows you to tap into the moment that our current asynchronous context is cancelled so that we can perform extra work:
	// if the parent asynchronous context is cancelled while performing this asynchronous work, the handler will be invoked.
//	try await withTaskCancellationHandler(
		// supply a closure that represents the work you want to perform when cancellation is detected
//		handler: {
			// when the parent Task is cancelled we need to explicitly communicate to both of the child Tasks, that we want to cancel them.
//			databaseTask.cancel()
//			networkTask.cancel()
//		},
		// the actual asynchronous work you want to execute.
//		operation: {
//			try await databaseTask.value
//			try await networkTask.value
//		}
//	)
//
//	return .init()
//}

// Now isCancelled is true and the task finished in 0.1sec.
// So it works, but the code keeps getting longer and stranger.
//6150B9C6-9131-4C12-AAC4-B4A086ECD5F8 Track analytics
//6150B9C6-9131-4C12-AAC4-B4A086ECD5F8 Making database query
//6150B9C6-9131-4C12-AAC4-B4A086ECD5F8 Making network request
//6150B9C6-9131-4C12-AAC4-B4A086ECD5F8 databaseQuery isCancelled true
//6150B9C6-9131-4C12-AAC4-B4A086ECD5F8 networkRequest isCancelled true
//6150B9C6-9131-4C12-AAC4-B4A086ECD5F8 Request finished in 0.10359597206115723


// Sometimes this withTaskCancellationHandler function really is necessary to use, but luckily for us there is an even simpler tool to use for this specific situation.
// There is a tool called `async let` that allows you to run multiple asynchronous units of work in parallel, while the code still reads linearly from top-to-bottom and cancellation happens as you would expect.

// let's assume the child operations return an actual value.

//struct Response: Encodable {
//	let user: User
//	let subscription: StripeSubscription
//}
//
//struct User: Encodable { var id: Int }
//func fetchUser() async throws -> User {
//	let requestId = RequestData.requestId!
//	defer { print(requestId, "databaseQuery", "isCancelled", Task.isCancelled) }
//	print(requestId, "Making database query")
//	try await Task.sleep(nanoseconds: 500_000_000)
//	print(requestId, "Finished database query")
//	return User(id: 42)
//}
//
//struct StripeSubscription: Encodable { var id: Int }
//func fetchSubscription() async throws -> StripeSubscription {
//	let requestId = RequestData.requestId!
//	defer { print(requestId, "networkRequest", "isCancelled", Task.isCancelled) }
//	print(requestId, "Making network request")
//	try await Task.sleep(nanoseconds: 500_000_000)
//	print(requestId, "Finished network request")
//	return StripeSubscription(id: 1729)
//}

//func response(_ request: URLRequest) async throws -> HTTPURLResponse {
//func response(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
//
//	let requestId = RequestData.requestId!
//	let start = RequestData.startDate!
//
//	defer { print(requestId, "Request finished in", Date().timeIntervalSince(start)) }
//
//	Task {
//		print(RequestData.requestId!, "Track analytics")
//	}
//
//	// use async let to bind some kind of database response to running the databaseQuery
//	// what we're doing here is async let bind.
//	async let user = fetchUser() // databaseQuery()
//	async let subscription = fetchSubscription() // networkRequest()
//
//	// we cannot just use the async let variable, we have to await it
//	// and even try it if operation that produced it is failable.
//	// try await print(user)
//	// look how linearly this reads
//	let jsonData = try await JSONEncoder().encode(Response(user: user, subscription: subscription))
//
//	return (jsonData, .init())
//}

// Let's go back without cancelling the task.
//RequestData.$requestId.withValue(UUID()) {
//	RequestData.$startDate.withValue(Date()) {
//		let task = Task {
//			_ = try await response(.init(url: .init(string: "https://www.pointfree.co")!))
//		}
//		Thread.sleep(forTimeInterval: 0.1)
		// task.cancel()
//	}
//}

// It runs linearly and returns response in about 0.545sec
//7A86E90B-0B77-4936-BB56-6CCCC361441E Making database query
//7A86E90B-0B77-4936-BB56-6CCCC361441E Track analytics
//7A86E90B-0B77-4936-BB56-6CCCC361441E Making network request
//7A86E90B-0B77-4936-BB56-6CCCC361441E Finished network request
//7A86E90B-0B77-4936-BB56-6CCCC361441E networkRequest isCancelled false
//7A86E90B-0B77-4936-BB56-6CCCC361441E Finished database query
//7A86E90B-0B77-4936-BB56-6CCCC361441E databaseQuery isCancelled false
//7A86E90B-0B77-4936-BB56-6CCCC361441E Request finished in 0.5450379848480225

// Now let's go back to cancelling
//RequestData.$requestId.withValue(UUID()) {
//	RequestData.$startDate.withValue(Date()) {
//		let task = Task {
//			_ = try await response(.init(url: .init(string: "https://www.pointfree.co")!))
//		}
//		Thread.sleep(forTimeInterval: 0.1)
//		task.cancel()
//	}
//}

// Notice how `async let` plays well with cancellation.
// We are performing concurrent work by fetching the user and subscription at the same time, and it’s not until we actually need to make use of it do we need to await. And even then we can just await a single time while both tasks run in parallel.

//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Making database query
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Track analytics
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Making network request
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 networkRequest isCancelled true
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 databaseQuery isCancelled true
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Request finished in 0.10472500324249268



// The async let construct works really well for when we need to run a statically known number of units of work in parallel and in a structured manner, but there’s another tool for dealing with an unknown number of units of work.
// It's called `task group`.
// it allows you to suspend while a dynamic number of tasks do their work and then resumes once all tasks are finished. You can even accumulate the output of each child task into a final output.

// To give this a spin, suppose that we wanted to fire up 1,000 tasks that simulate some complex process for procuring an integer, and then we want to sum up those 1,000 integers.

//Task {
//	withTaskGroup(
		// The first argument is a type of value that is returned from each child task the group spins up to do work
//		of: <#T##Sendable.Protocol#>,
		// the second argument is the type of value that will be ultimately returned from running the group of tasks, kind of like a reduce function
//		returning: <#T##GroupResult.Type#>,
		// the final argument is a closure where you actually do the work to add tasks to the group
//		body: <#T##(inout TaskGroup<Sendable>) async -> GroupResult#>
//	)
//}

// let's first see what this would look like in a world of just bare threads.
//var sum = 0
//for n in 1...1000 {
//	Thread.detachNewThread {
		// simulate doing some complex computation
//		Thread.sleep(forTimeInterval: 1)
		// then get the number for that index operation and add it to the sum.
		// notice we already get a warning from the compiler. which means there will be race conditions.
		// sum += n // ⚠️ Reference to var 'sum' is not concurrency-safe because it involves shared mutable state
//	}
//}

// let's still prove it for ourselves despite the warning.
// there is no easy way to wait for all of them to finish so we'll sleep for a while
//Thread.sleep(forTimeInterval: 1.1)
// we keep getting different number
//print("sum", sum)

// first run we got - sum 492625
// running it again we get - sum 467955


// With threads, we already know the code is not safe to run
// we should have encapsulated the variable in a class and have some locking in place and expose method to mutate the variable but that is a lot of work to do.
// Let's see what that looks like with task groups.
//func taskGroup() {
//	Task {
//		let sum = await withTaskGroup(
//			// the value each child task will return, for this example it's an Int
//			of: Int.self,
//			// once they are all complete, we will sum them together and return a sum from the task group
//			returning: Int.self,
//			// in this closure we will do the work to actually start adding tasks to the group
//			body: { group in
//				// we can add as many task as we want, this allows us do a dynamic number of tasks where as with async let we can only do a fixed number of tasks
//				for n in 1...1000 {
//					// all these child tasks will be run in parallel
//					group.addTask(operation: {
//						// in here we have an asynchronous context to do some asynchronous work and produce an integer
//						// we have to return an integer from here.
//						try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
//						return n
//					})
//				}
//				// we can be notified when they all finish by awaiting
//				// this allows us to suspend until every task in the group finishes
//				// await group.waitForAll()
//				// even better we can iterate over all the output as the child tasks finish, we can be instantly notified when an integer has been produced and we can act upon it like sum it up.
//				// Remember that since the tasks are run in parallel there is no guarantee of the order they will emit, and this can be an important distinction. but in this example we don't care about the order.
//				var sum = 0
//				// the group here conforms to a protocol known as AsyncSequence, which is analogous to the Sequence protocol in Swift, except its next method is allowed to suspend in order to perform asynchronous work.
//				// this is what allows us to do `for await`
//				for await int in group {
//					sum += int
//				}
//				return sum
//			}
//		)
//
//		// we get - sum 500500 every time we run this.
//		// no difference in value.
//		print("sum", sum)
//		// n*(n+1)/2, 1000*1001/2 = 500,500
//	}
//}

// So this code works without any race conditions and we didn’t even have to introduce an actor in order to isolate access to shared mutable state.
// Thanks to the way task group was designed we get the ability to accumulate the results of 1,000 tasks in a very simple manner.

// We can even use a different method on group to completely bypass adding the task if it detects the parent task has already been cancelled:
//Task {
//	let sum = await withTaskGroup(
//		of: Int.self,
//		returning: Int.self,
//		body: { group in
//			for n in 1...1000 {
//				group.addTaskUnlessCancelled(operation: {
//					try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
//					return n
//				})
//			}
//			var sum = 0
//			for await int in group {
//				sum += int
//			}
//			return sum
//		}
//	)
//
//	print("sum", sum)
//}

// However, if you want cancellation to “just work” automatically like we have seen with throwing asynchronous units of work, then we have to switch to a throwing task group:
// Now we can use try await instead of try? await we were using before to remove the compiler error of not being a a throwing context.
// It now means if this Task is cancelled, it will trickle all the way down into the child tasks of the group causing the `try await Task.sleep()` to throw, causing the `withThrowingTaskGroup` scope to throw and then everything gets cancelled.
//Task {
//	let sum = try await withThrowingTaskGroup(
//		of: Int.self,
//		returning: Int.self,
//		body: { group in
//			for n in 1...1000 {
//				group.addTask(operation: {
//					try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//					return n
//				})
//			}
//			var sum = 0
//			for try await int in group {
//				sum += int
//			}
//			return sum
//		}
//	)
//
//	print("sum", sum)
//}

// What if we don't have an async context available to us?
// It seems the only choice we have is to spin up a new Task, which we know is unstructured, in such scenario we really don't have an alternative.
// However, as the language and frameworks mature more and more, there will be fewer situations in which we need to do this.

// As long as we use only the tools of structured programming we can be sure that cancellation of this top level task will trickle down to all the child tasks, including the database query and network request that are run in parallel inside the response function.

//import SwiftUI
//Text("Hello")
// this allows running an asynchronous task when the view appears, and the task will be cancelled when the view disappears:
//	.task {
		// so we can take all the async work we did above and paste it here.
//		let sum = try? await withThrowingTaskGroup(
//			of: Int.self,
//			returning: Int.self,
//			body: { group in
//				for n in 1...1000 {
//					group.addTask(operation: {
//						try await Task.sleep(nanoseconds: NSEC_PER_SEC)
//						return n
//					})
//				}
//				var sum = 0
//				for try await int in group {
//					sum += int
//				}
//				return sum
//			}
//		)
//
//		print("sum", sum)
//	}


// As another example, Swift also allows us to implement the entry point of executables in such a way that they are automatically provided with an asynchronous context.
// as of Xcode 13.4 and Swift 5.6, we can’t perform asynchronous work at the top-level of the main.swift file:
// we get a compiler error here.
// This will work in a future version of Swift and Xcode.
// However before we have that new feature, there was another way of doing this which is to define a main function inside a Main struct marked with @main assuming we rename our main.swift file to something else.
// try await Task.sleep(nanoseconds: NSEC_PER_SEC) // 🛑 'async' call in a function that does not support concurrency


// Thread.sleep(forTimeInterval: 2)
