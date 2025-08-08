use pyo3::prelude::*;
use sha1::{Digest, Sha1};

#[pyclass]
#[derive(Clone)]
struct DUCOHasher {
    base_data: Vec<u8>,
}

#[pymethods]
impl DUCOHasher {
    #[new]
    pub fn new(data: &[u8]) -> Self {
        Self {
            base_data: data.to_vec(),
        }
    }

    #[allow(non_snake_case)]
    pub fn DUCOS1(&self, expected_hash: &[u8], diff: u128, job_mul: u128) -> u128 {
        let mut buffer = itoa::Buffer::new();
        let base_hasher = Sha1::new().chain_update(&self.base_data);

        for nonce in 0..(job_mul * diff + 1) {
            let mut hasher = base_hasher.clone();
            let str = buffer.format(nonce);
            hasher.update(str.as_bytes());

            let mut output = [0u8; 20];
            hasher.finalize_into((&mut output).into());

            if &output[..] == expected_hash {
                return nonce;
            }
        }
        0
    }
}

#[pymodule]
fn libducohasher(_py: Python, m: &Bound<PyModule>) -> PyResult<()> {
    m.add_class::<DUCOHasher>()?;
    Ok(())
}
