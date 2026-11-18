const API_BASE = '/api';

async function fetchSummary() {
  try {
    const res = await fetch(`${API_BASE}/summary`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    document.getElementById('total-kwh').innerText = `${data.total_kwh.toFixed(2)} kWh`;
    document.getElementById('plants-count').innerText = data.plants;
    document.getElementById('mean-irradiance').innerText = `${data.mean_irradiance.toFixed(2)} W/m²`;
    document.getElementById('peak-hour').innerText = `${data.peak_hour}:00`;
  } catch (err) {
    console.error('Failed to fetch summary:', err);
  }
}

async function fetchReadings() {
  const tbody = document.getElementById('readings-body');
  try {
    const res = await fetch(`${API_BASE}/readings`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    tbody.innerHTML = '';
    data.readings.slice(0, 15).forEach(r => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong>${r.plant}</strong></td>
        <td>${r.hour}:00</td>
        <td>${r.ts}</td>
        <td>${r.energy_kwh.toFixed(2)}</td>
        <td>${r.irradiance.toFixed(2)}</td>
      `;
      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Failed to fetch readings:', err);
    tbody.innerHTML = `<tr><td colspan="5" class="loading" style="color:red;">Failed to connect to API endpoint (${err.message})</td></tr>`;
  }
}

document.getElementById('refresh-btn').addEventListener('click', () => {
  fetchSummary();
  fetchReadings();
});

// Initial load
fetchSummary();
fetchReadings();
