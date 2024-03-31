import './App.css'
import Header from './components/Header'
import { Routes, Route } from 'react-router-dom'
import Swap from './components/Swap'
import { Faucet } from './components/Faucet'
import { Farm } from './components/Farm'
import { Ve } from './components/Ve'
import { Vote } from './components/Vote'
function App() {
  return (
    <>
      <div className="App">
        <Header />
        <div className="mainWindow">
          <Routes>
            <Route path="/" element={<Swap />} />
            <Route path="/ve" element={<Ve />} />

            <Route path="/farm" element={<Farm />} />
            <Route path="/vote" element={<Vote />} />
            <Route path="/faucet" element={<Faucet />} />
          </Routes>
        </div>
      </div>
    </>
  )
}

export default App
