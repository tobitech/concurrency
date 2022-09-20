@preconcurrency import Foundation

// Let's suppose for a moment that Swift doesn't have for-loops but that it has a `jump` statement.
// We could replicate what for-loops give us by using jump statements.
// suppose we wanted to write a loop that printed all the even numbers between 0 and 100
func unstructuredProgramming() {
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
	for x in 0...100 {
		for y in 0...100 {
			if x.isMultiple(of: 2) && y.isMultiple(of: 2) {
				print(x, y)
			}
		}
	}
}

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
func thread() {
	let lock = NSLock()
	lock.lock()
	defer { print("Finished") }
	print("Before")
	Thread.detachNewThread {
		
		print(Thread.current)
	}
	print("After")
	lock.unlock()
}

// thread()



// Let's re-explore the theoretical server function we played with in the past.
// Ignore the warning, they should go away in the next version of Swift they would have been audited for Sendability.
// This one below:
// ⚠️ Type 'UUID' does not conform to the 'Sendable' protocol
// Because the types `UUID` and `Date` haven't been audited for Sendability in our own Swift's version we can add a `@preconcurrency import to Foundation to suppress all those Sendable warnings.
enum RequestData {
	@TaskLocal static var requestId: UUID! // ⚠️ Type 'UUID' does not conform to the 'Sendable' protocol
	@TaskLocal static var startDate: Date! // ⚠️ Type 'UUID' does not conform to the 'Sendable' protocol
}

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

struct Response: Encodable {
	let user: User
	let subscription: StripeSubscription
}

struct User: Encodable { var id: Int }
func fetchUser() async throws -> User {
	let requestId = RequestData.requestId!
	defer { print(requestId, "databaseQuery", "isCancelled", Task.isCancelled) }
	print(requestId, "Making database query")
	try await Task.sleep(nanoseconds: 500_000_000)
	print(requestId, "Finished database query")
	return User(id: 42)
}

struct StripeSubscription: Encodable { var id: Int }
func fetchSubscription() async throws -> StripeSubscription {
	let requestId = RequestData.requestId!
	defer { print(requestId, "networkRequest", "isCancelled", Task.isCancelled) }
	print(requestId, "Making network request")
	try await Task.sleep(nanoseconds: 500_000_000)
	print(requestId, "Finished network request")
	return StripeSubscription(id: 1729)
}

//func response(_ request: URLRequest) async throws -> HTTPURLResponse {
func response(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
	
	let requestId = RequestData.requestId!
	let start = RequestData.startDate!
	
	defer { print(requestId, "Request finished in", Date().timeIntervalSince(start)) }
	
	Task {
		print(RequestData.requestId!, "Track analytics")
	}
	
	// use async let to bind some kind of database response to running the databaseQuery
	// what we're doing here is async let bind.
	async let user = fetchUser() // databaseQuery()
	async let subscription = fetchSubscription() // networkRequest()
	
	// we cannot just use the async let variable, we have to await it
	// and even try it if operation that produced it is failable.
	// try await print(user)
	// look how linearly this reads
	let jsonData = try await JSONEncoder().encode(Response(user: user, subscription: subscription))
	
	return (jsonData, .init())
}

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
RequestData.$requestId.withValue(UUID()) {
	RequestData.$startDate.withValue(Date()) {
		let task = Task {
			_ = try await response(.init(url: .init(string: "https://www.pointfree.co")!))
		}
		Thread.sleep(forTimeInterval: 0.1)
		task.cancel()
	}
}

// Notice how `async let` plays well with cancellation.
// We are performing concurrent work by fetching the user and subscription at the same time, and it’s not until we actually need to make use of it do we need to await. And even then we can just await a single time while both tasks run in parallel.

//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Making database query
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Track analytics
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Making network request
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 networkRequest isCancelled true
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 databaseQuery isCancelled true
//028DD6A8-89B2-4A45-9AF4-EF51E515B228 Request finished in 0.10472500324249268







Thread.sleep(forTimeInterval: 2)
