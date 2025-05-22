use std::time::Instant;

/// A properly antialiased calculator of the bandwidth.
pub struct BwEstimate {
    accum: f64,
    last_update: Instant,
}

impl BwEstimate {
    pub fn new(init_estimate: f64) -> Self {
        Self {
            accum: init_estimate,
            last_update: Instant::now(),
        }
    }

    pub fn sample(&mut self, delta: usize) {
        let now = Instant::now();
        let delta_t = now
            .saturating_duration_since(self.last_update)
            .as_secs_f64();
        let speed_sample = delta as f64 / delta_t;
        let decay_ratio = 1.0 / 2.0f64.powf(delta_t); // decay exponentially
        tracing::debug!(
            "speed {:.2} MB/s with sample at {:.2} MB/s",
            self.accum / 1_000_000.0,
            speed_sample / 1_000_000.0
        );
        self.accum = self.accum * decay_ratio + speed_sample * (1.0 - decay_ratio);
        self.last_update = now;
    }

    pub fn read(&self) -> f64 {
        self.accum
    }
}
