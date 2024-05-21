import SwiftUI
import Foundation

struct QuizTopic: Identifiable, Codable {
    let id = UUID()
    let title: String
    let desc: String
    let questions: [Question]
    let imageData: Data? // Store image data directly
    
    var imageName: String { // Computed property to determine image name based on title
        switch title {
        case "Science!":
            return "scienceImage"
        case "Marvel Super Heroes":
            return "superheroImage"
        case "Mathematics":
            return "mathImage"
        default:
            return "questionmark.circle"
        }
    }
    var image: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
}


struct ContentView: View {
    @State private var showingSettings = false
    @State private var newURL = "https://tednewardsandbox.site44.com/questions.json"
    @State private var quizTopics: [QuizTopic] = []
    @State private var alertMessage = ""
    @State private var timer: Timer?
    @State private var refreshInterval: TimeInterval = 60.0
    
    var body: some View {
        NavigationView {
            List(quizTopics) { topic in
                NavigationLink(destination: QuestionListView(topic: topic)) {
                    QuizTopicRow(topic: topic)
                }
            }
            .navigationBarTitle("IQuiz", displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gear")
                }
            )
            .onAppear {
                dataLoad(from: newURL)
                setupTimer()
            }
            .alert(isPresented: Binding<Bool>(
                get: { alertMessage != "" },
                set: { _,_ in }
            )) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .refreshable {
                dataLoad(from: newURL)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(newURL: $newURL, refreshInterval: $refreshInterval)
            }
        }
    }

    func dataLoad(from url: String) {
        guard let url = URL(string: url) else {
            alertMessage = "Invalid URL"
            return
        }

        if !Reachability.isConnectedToNetwork() {
            alertMessage = "Network is not available"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decoder = JSONDecoder()
                    let quizData = try decoder.decode([QuizTopic].self, from: data)
                    DispatchQueue.main.async {
                        self.quizTopics = quizData
                        UserDefaults.standard.set(url.absoluteString, forKey: "quizDataURL")
                    }
                } catch {
                    DispatchQueue.main.async {
                        alertMessage = "Error decoding JSON: \(error.localizedDescription)"
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Error fetching data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            dataLoad(from: newURL)
        }
    }
}

struct QuizTopicRow: View {
    let topic: QuizTopic
    
    var body: some View {
        HStack(spacing: 15) {
            if let uiImage = UIImage(named: topic.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .padding(8)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 2)
                    )
            } else {
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .padding(8)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(topic.title)
                    .font(.headline)
                    .foregroundColor(Color.black)
                    .padding(.bottom, 3) // Add padding below the title
                Text(topic.desc)
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: Color.gray.opacity(0.4), radius: 6, x: 0, y: 3) // Increased shadow radius
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct Question: Codable {
    let text: String
    let answer: String
    let answers: [String]
}

struct QuestionListView: View {
    let topic: QuizTopic
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [String?] = []
    @State private var isAnswerViewPresented = false
    @State private var userScore = 0

    var totalQuestions: Int {
        topic.questions.count
    }

    var currentQuestion: Question {
        topic.questions[currentQuestionIndex]
    }

    var body: some View {
        VStack {
            if currentQuestionIndex < topic.questions.count {
                if isAnswerViewPresented {
                    AnswerView(question: currentQuestion, correctAnswer: currentQuestion.answers[Int(currentQuestion.answer)! - 1], userAnswer: userAnswers[currentQuestionIndex], dismissAction: {
                        isAnswerViewPresented = false
                        currentQuestionIndex += 1
                    })
                    .transition(.scale)
                } else {
                    VStack(spacing: 20) {
                        ProgressView(value: Double(currentQuestionIndex), total: Double(totalQuestions))
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 10) {
                            Text(currentQuestion.text) // Display question text
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            ForEach(0..<currentQuestion.answers.count, id: \.self) { index in
                                Button(action: {
                                    let userAnswer = currentQuestion.answers[index]
                                    userAnswers.append(userAnswer)
                                    if userAnswer == currentQuestion.answers[Int(currentQuestion.answer)! - 1] {
                                        userScore += 1
                                    }
                                    isAnswerViewPresented = true
                                }) {
                                    Text(currentQuestion.answers[index])
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .shadow(color: Color.gray.opacity(0.4), radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                        .padding()
                        .transition(.scale)
                    }
                }
            } else {
                FinishedView(score: userScore, totalQuestions: totalQuestions)
                    .transition(.scale)
            }
        }
    }
}




struct QuestionView: View {
    let question: Question
    let didSelectAnswerIndex: (Int) -> Void
    @State private var selectedAnswerIndex: Int?

    var body: some View {
        VStack(spacing: 20) {
            Text(question.text)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()

            ForEach(question.answers.indices, id: \.self) { index in
                Button(action: {
                    selectedAnswerIndex = index
                    didSelectAnswerIndex(index)
                }) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(selectedAnswerIndex == index ? Color.blue : Color.white)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(selectedAnswerIndex == index ? Color.blue : Color.gray, lineWidth: 2)
                                )
                                .padding(.trailing)
                            if selectedAnswerIndex == index {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }

                        Text(question.answers[index])
                            .foregroundColor(.black)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedAnswerIndex == index ? Color.blue.opacity(0.1) : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedAnswerIndex == index ? Color.blue : Color.gray, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            Button(action: {
                // Perform action when Next button is tapped
                didSelectAnswerIndex(selectedAnswerIndex ?? 0)
            }) {
                Text("Next")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                    .shadow(color: Color.blue.opacity(0.7), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal, 20)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.gray.opacity(0.4), radius: 8, x: 0, y: 4)
        .padding(20)
    }
}





struct SwiftUIImage: View {
    var uiImage: UIImage?

    var body: some View {
        if let uiImage = uiImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30) // Adjust size as needed
        } else {
            Image(systemName: "questionmark.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30) // Default size
        }
    }
}

struct SettingsView: View {
    @Binding var newURL: String
    @Binding var refreshInterval: TimeInterval
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Data Source")
                    .font(.headline)
                    .padding(.top)
                
                TextField("Enter URL", text: $newURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }
            
            VStack(alignment: .leading) {
                Text("Refresh Interval (seconds)")
                    .font(.headline)
                    .padding(.top)
                
                TextField("Enter seconds", value: $refreshInterval, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }
            
            Divider()
            
            Button(action: {
                UserDefaults.standard.set(newURL, forKey: "quizDataURL")
            }) {
                Text("Save Settings")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}

struct AnswerView: View {
    let question: Question
    let correctAnswer: String
    let userAnswer: String?
    let dismissAction: () -> Void

    var isAnswerCorrect: Bool {
        userAnswer == correctAnswer
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Answer:")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding()

            Text(question.text)
                .padding()
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.black)

            if let userAnswer = userAnswer {
                Text("Your Answer: \(userAnswer)")
                    .padding(.bottom, 20)
                    .font(.headline)
                    .foregroundColor(isAnswerCorrect ? .green : .red)
            }

            Text("Correct Answer: \(correctAnswer)")
                .padding(.bottom, 20)
                .font(.headline)
                .foregroundColor(.green)

            if isAnswerCorrect {
                Text("+1")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Button(action: {
                dismissAction()
            }) {
                Text("Next Question")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.gray.opacity(0.4), radius: 8, x: 0, y: 4)
        .padding(20)
    }
}


struct Reachability {
    static func isConnectedToNetwork() -> Bool {
        return true // Placeholder implementation for network check
    }
}
struct FinishedView: View {
    let score: Int
    let totalQuestions: Int
    
    @Environment(\.presentationMode) var presentationMode

    var scoreText: String {
        let percentage = Double(score) / Double(totalQuestions)
        switch percentage {
        case 1.0:
            return "Perfect!"
        case 0.9..<1.0:
            return "Almost perfect!"
        case 0.7..<0.9:
            return "Great job!"
        case 0.5..<0.7:
            return "Not bad!"
        default:
            return "Keep practicing!"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Quiz Completed!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.blue)
            
            Text(scoreText)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(Color.green)
                .padding(.top, 20)
            
            HStack {
                Text("Your Score:")
                    .font(.headline)
                    .foregroundColor(Color.black)
                Text("\(score) / \(totalQuestions)")
                    .font(.headline)
                    .foregroundColor(Color.blue)
            }
            .padding(.top, 10)
            
            Spacer()
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Finish")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.bottom)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.gray.opacity(0.4), radius: 8, x: 0, y: 4)
        .padding(20)
    }
}

